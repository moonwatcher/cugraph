# Copyright (c) 2023, NVIDIA CORPORATION.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from typing import Optional, Union
from collections import defaultdict

from cugraph.utilities.utils import import_optional
from pylibcugraphops.pytorch.operators import mha_gat_n2n

from .base import BaseConv

torch = import_optional("torch")
torch_geometric = import_optional("torch_geometric")


class HeteroGATConv(BaseConv):
    r"""The graph attentional operator on heterogeneous graphs, where a separate
    `GATConv` is applied on the homogeneous graph for each edge type. Compared
    with directly wrapping `GATConv`s with `HeteroConv`, `HeteroGATConv` fuses
    all the linear transformation associated with each node type together into 1
    GEMM call, to improve the performance on GPUs.

    Parameters
    ----------
    in_channels : int or Dict[str, int])
        Size of each input sample of every node type.

    out_channels : int
        Size of each output sample.

    node_types : List[str]
        List of Node types.

    edge_types : List[Tuple[str, str, str]]
        List of Edge types.

    heads : int, optional (default=1)
        Number of multi-head-attentions.

    concat : bool, optional (default=True):
        If set to :obj:`False`, the multi-head attentions are averaged instead
        of concatenated.

    negative_slope : float, optional (default=0.2)
        LeakyReLU angle of the negative slope.

    bias : bool, optional (default=True)
        If set to :obj:`False`, the layer will not learn an additive bias.

    aggr : str, optional (default="sum")
        The aggregation scheme to use for grouping node embeddings generated by
        different relations. Choose from "sum", "mean", "min", "max".
    """

    def __init__(
        self,
        in_channels: Union[int, dict[str, int]],
        out_channels: int,
        node_types: list[str],
        edge_types: list[tuple[str, str, str]],
        heads: int = 1,
        concat: bool = True,
        negative_slope: float = 0.2,
        bias: bool = True,
        aggr: str = "sum",
    ):
        major, minor, patch = torch_geometric.__version__.split(".")[:3]
        pyg_version = tuple(map(int, [major, minor, patch]))
        if pyg_version < (2, 4, 0):
            raise RuntimeError(f"{self.__class__.__name__} requires pyg >= 2.4.0.")

        super().__init__()

        if isinstance(in_channels, int):
            in_channels = dict.fromkeys(node_types, in_channels)
        self.in_channels = in_channels
        self.out_channels = out_channels

        self.node_types = node_types
        self.edge_types = edge_types
        self.num_heads = heads
        self.concat_heads = concat

        self.negative_slope = negative_slope
        self.aggr = aggr

        self.relations_per_ntype = defaultdict(lambda: ([], []))

        lin_weights = dict.fromkeys(self.node_types)
        attn_weights = dict.fromkeys(self.edge_types)
        biases = dict.fromkeys(self.edge_types)

        ParameterDict = torch_geometric.nn.parameter_dict.ParameterDict

        for edge_type in self.edge_types:
            src_type, _, dst_type = edge_type
            self.relations_per_ntype[src_type][0].append(edge_type)
            if src_type != dst_type:
                self.relations_per_ntype[dst_type][1].append(edge_type)

            attn_weights[edge_type] = torch.empty(
                2 * self.num_heads * self.out_channels
            )

            if bias and concat:
                biases[edge_type] = torch.empty(self.num_heads * out_channels)
            elif bias:
                biases[edge_type] = torch.empty(out_channels)
            else:
                biases[edge_type] = None

        for ntype in self.node_types:
            n_src_rel = len(self.relations_per_ntype[ntype][0])
            n_dst_rel = len(self.relations_per_ntype[ntype][1])
            n_rel = n_src_rel + n_dst_rel

            lin_weights[ntype] = torch.empty(
                (n_rel * self.num_heads * self.out_channels, self.in_channels[ntype])
            )

        self.lin_weights = ParameterDict(lin_weights)
        self.attn_weights = ParameterDict(attn_weights)

        if bias:
            self.bias = ParameterDict(biases)
        else:
            self.register_parameter("bias", None)

        self.reset_parameters()

    def split_tensors(
        self, x_fused_dict: dict[str, torch.Tensor], dim: int
    ) -> tuple[dict[str, torch.Tensor], dict[str, torch.Tensor]]:
        """Split fused tensors into chunks based on edge types.

        Parameters
        ----------
        x_fused_dict : dict[str, torch.Tensor]
            A dictionary to hold node feature for each node type. The key is
            node type; the value is a fused tensor that account for all
            relations for that node type.

        dim : int
            Dimension along which to split the fused tensor.

        Returns
        -------
        x_src_dict : dict[str, torch.Tensor]
            A dictionary to hold source node feature for each relation graph.

        x_dst_dict : dict[str, torch.Tensor]
            A dictionary to hold destination node feature for each relation graph.
        """
        x_src_dict = dict.fromkeys(self.edge_types)
        x_dst_dict = dict.fromkeys(self.edge_types)

        for ntype, t in x_fused_dict.items():
            n_src_rel = len(self.relations_per_ntype[ntype][0])
            n_dst_rel = len(self.relations_per_ntype[ntype][1])
            n_rel = n_src_rel + n_dst_rel
            t_list = torch.chunk(t, chunks=n_rel, dim=dim)

            for i, src_rel in enumerate(self.relations_per_ntype[ntype][0]):
                x_src_dict[src_rel] = t_list[i]

            for i, dst_rel in enumerate(self.relations_per_ntype[ntype][1]):
                x_dst_dict[dst_rel] = t_list[i + n_src_rel]

        return x_src_dict, x_dst_dict

    def reset_parameters(self, seed: Optional[int] = None):
        if seed is not None:
            torch.manual_seed(seed)

        w_src, w_dst = self.split_tensors(self.lin_weights, dim=0)

        for edge_type in self.edge_types:
            src_type, _, dst_type = edge_type

            # lin_src
            torch_geometric.nn.inits.glorot(w_src[edge_type])

            # lin_dst
            if src_type != dst_type:
                torch_geometric.nn.inits.glorot(w_dst[edge_type])

            # attn_weights
            torch_geometric.nn.inits.glorot(
                self.attn_weights[edge_type].view(-1, self.num_heads, self.out_channels)
            )

            # bias
            if self.bias is not None:
                torch_geometric.nn.inits.zeros(self.bias[edge_type])

    def forward(
        self,
        x_dict: dict[str, torch.Tensor],
        edge_index_dict: dict[tuple[str, str, str], torch.Tensor],
    ) -> dict[str, torch.Tensor]:
        feat_dict = dict.fromkeys(x_dict.keys())

        for ntype, x in x_dict.items():
            feat_dict[ntype] = x @ self.lin_weights[ntype].T

        x_src_dict, x_dst_dict = self.split_tensors(feat_dict, dim=1)

        out_dict = defaultdict(list)

        for edge_type, edge_index in edge_index_dict.items():
            src_type, _, dst_type = edge_type

            csc = BaseConv.to_csc(
                edge_index, (x_dict[src_type].size(0), x_dict[dst_type].size(0))
            )

            if src_type == dst_type:
                graph = self.get_cugraph(
                    csc,
                    bipartite=False,
                )
                out = mha_gat_n2n(
                    x_src_dict[edge_type],
                    self.attn_weights[edge_type],
                    graph,
                    num_heads=self.num_heads,
                    activation="LeakyReLU",
                    negative_slope=self.negative_slope,
                    concat_heads=self.concat_heads,
                )

            else:
                graph = self.get_cugraph(
                    csc,
                    bipartite=True,
                )
                out = mha_gat_n2n(
                    (x_src_dict[edge_type], x_dst_dict[edge_type]),
                    self.attn_weights[edge_type],
                    graph,
                    num_heads=self.num_heads,
                    activation="LeakyReLU",
                    negative_slope=self.negative_slope,
                    concat_heads=self.concat_heads,
                )

            if self.bias is not None:
                out = out + self.bias[edge_type]

            out_dict[dst_type].append(out)

        for key, value in out_dict.items():
            out_dict[key] = torch_geometric.nn.conv.hetero_conv.group(value, self.aggr)

        return out_dict

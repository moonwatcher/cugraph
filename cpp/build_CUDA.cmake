#=============================================================================
# Copyright (c) 2018-2024, NVIDIA CORPORATION.
#
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
#=============================================================================


message(STATUS "Configuring build for ${PROJECT_NAME}")

set(CMAKE_CUDA_ARCHITECTURES "70;80;90")

find_package(CUDAToolkit REQUIRED)
#set(CMAKE_CUDA_USE_RESPONSE_FILE_FOR_INCLUDES 0)
if (CUDAToolkit_FOUND)
    if( CUDAToolkit_VERSION VERSION_LESS 10)
        message(FATAL_ERROR "CUDA compiler version must be at least 12.2")
    endif()   
    message(STATUS "CUDA Toolkit found: ${CUDAToolkit_VERSION}")
else()
    message(FATAL_ERROR "CUDA Toolkit not found")
endif()


if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND
   CMAKE_CXX_COMPILER_VERSION VERSION_LESS 9.3)
    message(FATAL_ERROR "GCC compiler must be at least 9.3")
endif()

######### Set build configuration ############

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(STATUS "Debug build configuration")
elseif (CMAKE_BUILD_TYPE STREQUAL "Release")
    message(STATUS "Release build configuration")
else()
    message(STATUS "No build configuration set, assuming release configuration")
    set(CMAKE_BUILD_TYPE "Release")
endif() 

################################################################################
# - User Options  --------------------------------------------------------------

option(BUILD_SHARED_LIBS "Build cuGraph shared libraries" OFF)
option(BUILD_CUGRAPH_MG_TESTS "Build cuGraph multigpu algorithm tests" OFF)
option(CMAKE_CUDA_LINEINFO "Enable the -lineinfo option for nvcc (useful for cuda-memcheck / profiler" OFF)
option(BUILD_TESTS "Configure CMake to build tests" ON)
option(USE_CUGRAPH_OPS "Enable all functions that call cugraph-ops" OFF)
option(USE_RAFT_STATIC "Build raft as a static library" OFF)
option(CUGRAPH_COMPILE_RAFT_LIB "Compile the raft library instead of using it header-only" OFF)
option(CUDA_STATIC_RUNTIME "Statically link the CUDA toolkit runtime and libraries" OFF)
option(CUGRAPH_USE_CUGRAPH_OPS_STATIC "Build and statically link the cugraph-ops library" OFF)
option(CUGRAPH_EXCLUDE_CUGRAPH_OPS_FROM_ALL "Exclude cugraph-ops targets from cuGraph's 'all' target" OFF)
option(ALLOW_CLONE_CUGRAPH_OPS "Whether to attempt to clone cugraph-ops when a local version is not available" OFF)

message(VERBOSE "CUGRAPH: CUDA_STATIC_RUNTIME=${CUDA_STATIC_RUNTIME}")
message(VERBOSE "CUGRAPH: CUGRAPH_USE_CUGRAPH_OPS_STATIC=${CUGRAPH_USE_CUGRAPH_OPS_STATIC}")
message(VERBOSE "CUGRAPH: CUGRAPH_EXCLUDE_CUGRAPH_OPS_FROM_ALL=${CUGRAPH_EXCLUDE_CUGRAPH_OPS_FROM_ALL}")

################################################################################
# - compiler options -----------------------------------------------------------

set(CUGRAPH_C_FLAGS "")
set(CUGRAPH_CXX_FLAGS -DCUTLASS_NAMESPACE=raft_cutlass -DLIBCUDACXX_ENABLE_EXPERIMENTAL_MEMORY_RESOURCE -DRAFT_SYSTEM_LITTLE_ENDIAN=1 -DSPDLOG_FMT_EXTERNAL -DTHRUST_DEVICE_SYSTEM=THRUST_DEVICE_SYSTEM_CUDA -DTHRUST_DISABLE_ABI_NAMESPACE -DTHRUST_HOST_SYSTEM=THRUST_HOST_SYSTEM_CPP -DTHRUST_IGNORE_ABI_NAMESPACE_ERROR -Dcugraph_EXPORTS)
set(CUGRAPH_CUDA_FLAGS -DCUTLASS_NAMESPACE=raft_cutlass -DLIBCUDACXX_ENABLE_EXPERIMENTAL_MEMORY_RESOURCE -DRAFT_SYSTEM_LITTLE_ENDIAN=1 -DSPDLOG_FMT_EXTERNAL -DTHRUST_DEVICE_SYSTEM=THRUST_DEVICE_SYSTEM_CUDA -DTHRUST_DISABLE_ABI_NAMESPACE -DTHRUST_HOST_SYSTEM=THRUST_HOST_SYSTEM_CPP -DTHRUST_IGNORE_ABI_NAMESPACE_ERROR -Dcugraph_EXPORTS)

if(CMAKE_COMPILER_IS_GNUCXX)
    list(APPEND CUGRAPH_CXX_FLAGS -Werror -Wno-error=deprecated-declarations)
endif(CMAKE_COMPILER_IS_GNUCXX)

message("-- Building for GPU_ARCHS = ${CMAKE_CUDA_ARCHITECTURES}")

if(NOT USE_CUGRAPH_OPS)
    message(STATUS "Disabling functions that reference cugraph-ops")
    list(APPEND CUGRAPH_C_FLAGS -DNO_CUGRAPH_OPS)
    list(APPEND CUGRAPH_CXX_FLAGS -DNO_CUGRAPH_OPS)
    list(APPEND CUGRAPH_CUDA_FLAGS -DNO_CUGRAPH_OPS)
endif()

list(APPEND CUGRAPH_C_FLAGS    -DFMT_HEADER_ONLY )
list(APPEND CUGRAPH_CXX_FLAGS  -DFMT_HEADER_ONLY )
list(APPEND CUGRAPH_CUDA_FLAGS -DFMT_HEADER_ONLY  )



list(APPEND CUGRAPH_CUDA_FLAGS --expt-extended-lambda --expt-relaxed-constexpr)
list(APPEND CUGRAPH_CUDA_FLAGS -Werror=cross-execution-space-call -Wno-deprecated-declarations -Xptxas=--disable-warnings)
list(APPEND CUGRAPH_CUDA_FLAGS -Xcompiler=-Wall,-Wno-error=sign-compare,-Wno-error=unused-but-set-variable)
list(APPEND CUGRAPH_CUDA_FLAGS -Xfatbin=-compress-all)

list(APPEND CUGRAPH_CUDA_FLAGS -I/usr/local/cuda/include )
#list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/nvtx )
list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cccl/thrust )
list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cccl/cub/ )
list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cccl/cub/cub/ )
list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cccl/libcudacxx/include )
list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/rmm/ )
list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/fmt/include )
list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/spdlog/include )
list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/raft/include )
list(APPEND CUGRAPH_CUDA_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cutlass/include )

 #list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/nvtx )
list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cccl/thrust )
list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cccl/cub/ )
list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cccl/cub/cub/ )
list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cccl/libcudacxx/include )
list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/rmm/ )
list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/fmt/include )
list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/spdlog/include )
list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/raft/include )
list(APPEND CUGRAPH_CXX_FLAGS -I${CMAKE_CURRENT_SOURCE_DIR}/include/cutlass/include )
list(APPEND CUGRAPH_CXX_FLAGS -I/usr/local/cuda/include )



# Option to enable line info in CUDA device compilation to allow introspection when profiling /
# memchecking
if (CMAKE_CUDA_LINEINFO)
    list(APPEND CUGRAPH_CUDA_FLAGS -lineinfo)
endif()

# Debug options
if(CMAKE_BUILD_TYPE MATCHES Debug)
    message(STATUS "Building with debugging flags")
    list(APPEND CUGRAPH_CUDA_FLAGS -G -Xcompiler=-rdynamic)
endif()


###################################################################################################
# - find CPM based dependencies  ------------------------------------------------------------------

if (BUILD_CUGRAPH_MTMG_TESTS)
  include(cmake/thirdparty/get_ucp.cmake)
endif()

if(BUILD_TESTS)
    # this requires apt install libgtest-dev
    find_package(GTest REQUIRED)
endif()

################################################################################
# - libcugraph library target --------------------------------------------------

# NOTE: The most expensive compilations are listed first
#       since ninja will run them in parallel in this order,
#       which should give us a better parallel schedule.

set(CUGRAPH_SOURCES
      src/utilities/shuffle_vertices.cu
      src/detail/permute_range.cu
      src/utilities/shuffle_vertex_pairs.cu
      src/detail/collect_local_vertex_values.cu
      src/detail/groupby_and_count.cu
      src/detail/collect_comm_wrapper.cu
      src/sampling/random_walks_mg.cu
      src/community/detail/common_methods_mg.cu
      src/community/detail/common_methods_sg.cu
      src/community/detail/refine_sg.cu
      src/community/detail/refine_mg.cu
      src/community/edge_triangle_count_sg.cu
      src/community/detail/maximal_independent_moves_sg.cu
      src/community/detail/maximal_independent_moves_mg.cu
      src/detail/utility_wrappers.cu
      src/structure/graph_view_mg.cu
      src/structure/remove_self_loops.cu
      src/structure/remove_multi_edges.cu
      src/utilities/path_retrieval.cu
      src/structure/legacy/graph.cu
      src/linear_assignment/legacy/hungarian.cu
      src/link_prediction/jaccard_sg.cu
      src/link_prediction/sorensen_sg.cu
      src/link_prediction/overlap_sg.cu
      src/link_prediction/jaccard_mg.cu
      src/link_prediction/sorensen_mg.cu
      src/link_prediction/overlap_mg.cu
      src/layout/legacy/force_atlas2.cu
      src/converters/legacy/COOtoCSR.cu
      src/community/legacy/spectral_clustering.cu
      src/community/louvain_sg.cu
      src/community/louvain_mg.cu
      src/community/leiden_sg.cu
      src/community/leiden_mg.cu
      src/community/ecg_sg.cu
      src/community/ecg_mg.cu
      src/community/legacy/louvain.cu
      src/community/legacy/ecg.cu
      src/community/egonet_sg.cu
      src/community/egonet_mg.cu
      src/community/k_truss_sg.cu
      src/sampling/random_walks.cu
      src/sampling/random_walks_sg.cu
      src/sampling/detail/prepare_next_frontier_sg.cu
      src/sampling/detail/prepare_next_frontier_mg.cu
      src/sampling/detail/gather_one_hop_edgelist_sg.cu
      src/sampling/detail/gather_one_hop_edgelist_mg.cu
      src/sampling/detail/remove_visited_vertices_from_frontier.cu
      src/sampling/detail/sample_edges_sg.cu
      src/sampling/detail/sample_edges_mg.cu
      src/sampling/detail/shuffle_and_organize_output_mg.cu
      src/sampling/uniform_neighbor_sampling_mg.cpp
      src/sampling/uniform_neighbor_sampling_sg.cpp
      src/sampling/renumber_sampled_edgelist_sg.cu
      src/sampling/sampling_post_processing_sg.cu
      src/cores/core_number_sg.cu
      src/cores/core_number_mg.cu
      src/cores/k_core_sg.cu
      src/cores/k_core_mg.cu
      src/components/legacy/connectivity.cu
      src/generators/generate_rmat_edgelist.cu
      src/generators/generate_bipartite_rmat_edgelist.cu
      src/generators/generator_tools.cu
      src/generators/simple_generators.cu
      src/generators/erdos_renyi_generator.cu
      src/structure/graph_sg.cu
      src/structure/graph_mg.cu
      src/structure/graph_view_sg.cu
      src/structure/decompress_to_edgelist_sg.cu
      src/structure/decompress_to_edgelist_mg.cu
      src/structure/symmetrize_graph_sg.cu
      src/structure/symmetrize_graph_mg.cu
      src/structure/transpose_graph_sg.cu
      src/structure/transpose_graph_mg.cu
      src/structure/transpose_graph_storage_sg.cu
      src/structure/transpose_graph_storage_mg.cu
      src/structure/coarsen_graph_sg.cu
      src/structure/coarsen_graph_mg.cu
      src/structure/graph_weight_utils_mg.cu
      src/structure/graph_weight_utils_sg.cu
      src/structure/renumber_edgelist_sg.cu
      src/structure/renumber_edgelist_mg.cu
      src/structure/renumber_utils_sg.cu
      src/structure/renumber_utils_mg.cu
      src/structure/relabel_sg.cu
      src/structure/relabel_mg.cu
      src/structure/induced_subgraph_sg.cu
      src/structure/induced_subgraph_mg.cu
      src/structure/select_random_vertices_sg.cu
      src/structure/select_random_vertices_mg.cu
      src/traversal/extract_bfs_paths_sg.cu
      src/traversal/extract_bfs_paths_mg.cu
      src/traversal/bfs_sg.cu
      src/traversal/bfs_mg.cu
      src/traversal/sssp_sg.cu
      src/traversal/od_shortest_distances_sg.cu
      src/traversal/sssp_mg.cu
      src/link_analysis/hits_sg.cu
      src/link_analysis/hits_mg.cu
      src/link_analysis/pagerank_sg.cu
      src/link_analysis/pagerank_mg.cu
      src/centrality/katz_centrality_sg.cu
      src/centrality/katz_centrality_mg.cu
      src/centrality/eigenvector_centrality_sg.cu
      src/centrality/eigenvector_centrality_mg.cu
      src/centrality/betweenness_centrality_sg.cu
      src/centrality/betweenness_centrality_mg.cu
      src/tree/legacy/mst.cu
      src/components/weakly_connected_components_sg.cu
      src/components/weakly_connected_components_mg.cu
      src/components/mis_sg.cu
      src/components/mis_mg.cu
      src/components/vertex_coloring_sg.cu
      src/components/vertex_coloring_mg.cu
      src/structure/create_graph_from_edgelist_sg.cu
      src/structure/create_graph_from_edgelist_mg.cu
      src/structure/symmetrize_edgelist_sg.cu
      src/structure/symmetrize_edgelist_mg.cu
      src/community/triangle_count_sg.cu
      src/community/triangle_count_mg.cu
      src/traversal/k_hop_nbrs_sg.cu
      src/traversal/k_hop_nbrs_mg.cu
      src/mtmg/vertex_result.cu
)

# commented out because not using cugraphops right now
#if(USE_CUGRAPH_OPS)
#    list(APPEND CUGRAPH_SOURCES
#        src/sampling/neighborhood.cu
#    )
#endif()

add_library(cugraph ${CUGRAPH_SOURCES})

if( USE_CUDA )
    set_target_properties(cugraph
        PROPERTIES BUILD_RPATH                         "\$ORIGIN"
                INSTALL_RPATH                       "\$ORIGIN"
                # set target compile options
                CXX_STANDARD                        17
                CXX_STANDARD_REQUIRED               ON
                CUDA_STANDARD                       17
                CUDA_STANDARD_REQUIRED              ON
                POSITION_INDEPENDENT_CODE           ON
                INTERFACE_POSITION_INDEPENDENT_CODE ON
    )
    target_compile_options(cugraph
                PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${CUGRAPH_CXX_FLAGS}>"
                        "$<$<COMPILE_LANGUAGE:CUDA>:${CUGRAPH_CUDA_FLAGS}>"
    )
endif()


# Per-thread default stream option see https://docs.nvidia.com/cuda/cuda-runtime-api/stream-sync-behavior.html
# The per-thread default stream does not synchronize with other streams
target_compile_definitions(cugraph PUBLIC CUDA_API_PER_THREAD_DEFAULT_STREAM)

file(WRITE "${CUGRAPH_BINARY_DIR}/fatbin.ld"
[=[
SECTIONS
{
  .nvFatBinSegment : { *(.nvFatBinSegment) }
  .nv_fatbin : { *(.nv_fatbin) }
}
]=])
target_link_options(cugraph PRIVATE "${CUGRAPH_BINARY_DIR}/fatbin.ld")

add_library(cugraph::cugraph ALIAS cugraph)

################################################################################
# - include paths --------------------------------------------------------------

target_include_directories(cugraph
    PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/../thirdparty"
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
    PUBLIC
        "${CUDAToolkit_INCLUDE_DIRS}"
        "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
        "$<INSTALL_INTERFACE:include>"
)

################################################################################
# - link libraries -------------------------------------------------------------
if( USE_CUDA )
target_link_libraries(cugraph
    PUBLIC
    CUDA::cublas
    CUDA::cusparse
    CUDA::curand
    CUDA::cusolver
    $<BUILD_LOCAL_INTERFACE:CUDA::toolkit>
#        $<TARGET_NAME_IF_EXISTS:cugraph-ops::cugraph-ops++>
#    PRIVATE
#        ${COMPILED_RAFT_LIB}
#        cuco::cuco
    )
endif()

################################################################################
# - C-API library --------------------------------------------------------------

add_library(cugraph_c
        src/c_api/resource_handle.cpp
        src/c_api/array.cpp
        src/c_api/degrees.cu
        src/c_api/degrees_result.cpp
        src/c_api/error.cpp
        src/c_api/graph_sg.cpp
        src/c_api/graph_mg.cpp
        src/c_api/graph_functions.cpp
        src/c_api/pagerank.cpp
        src/c_api/katz.cpp
        src/c_api/centrality_result.cpp
        src/c_api/eigenvector_centrality.cpp
        src/c_api/betweenness_centrality.cpp
        src/c_api/core_number.cpp
        src/c_api/k_truss.cpp
        src/c_api/core_result.cpp
        src/c_api/extract_ego.cpp
        src/c_api/ecg.cpp
        src/c_api/k_core.cpp
        src/c_api/hierarchical_clustering_result.cpp
        src/c_api/induced_subgraph.cpp
        src/c_api/capi_helper.cu
        src/c_api/legacy_spectral.cpp
        src/c_api/legacy_ecg.cpp
        src/c_api/graph_helper_sg.cu
        src/c_api/graph_helper_mg.cu
        src/c_api/graph_generators.cpp
        src/c_api/induced_subgraph_result.cpp
        src/c_api/hits.cpp
        src/c_api/bfs.cpp
        src/c_api/sssp.cpp
        src/c_api/extract_paths.cpp
        src/c_api/random_walks.cpp
        src/c_api/random.cpp
        src/c_api/similarity.cpp
        src/c_api/leiden.cpp
        src/c_api/louvain.cpp
        src/c_api/triangle_count.cpp
        src/c_api/uniform_neighbor_sampling.cpp
        src/c_api/labeling_result.cpp
        src/c_api/weakly_connected_components.cpp
        src/c_api/strongly_connected_components.cpp
        src/c_api/allgather.cpp
        )
add_library(cugraph::cugraph_c ALIAS cugraph_c)

# Currently presuming we aren't calling any CUDA kernels in cugraph_c

set_target_properties(cugraph_c
    PROPERTIES BUILD_RPATH                         "\$ORIGIN"
               INSTALL_RPATH                       "\$ORIGIN"
               # set target compile options
               CXX_STANDARD                        17
               CXX_STANDARD_REQUIRED               ON
               CUDA_STANDARD                       17
               CUDA_STANDARD_REQUIRED              ON
               POSITION_INDEPENDENT_CODE           ON
               INTERFACE_POSITION_INDEPENDENT_CODE ON
)

target_compile_options(cugraph_c
             PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${CUGRAPH_CXX_FLAGS}>"
                     "$<$<COMPILE_LANGUAGE:CUDA>:${CUGRAPH_CUDA_FLAGS}>"
)

# Per-thread default stream option see https://docs.nvidia.com/cuda/cuda-runtime-api/stream-sync-behavior.html
# The per-thread default stream does not synchronize with other streams
target_compile_definitions(cugraph_c PUBLIC CUDA_API_PER_THREAD_DEFAULT_STREAM)

target_link_options(cugraph_c PRIVATE "${CUGRAPH_BINARY_DIR}/fatbin.ld")

################################################################################
# - C-API include paths --------------------------------------------------------

target_include_directories(cugraph_c
    PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
    PUBLIC
        "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
        "$<INSTALL_INTERFACE:include>"
)


################################################################################
# - C-API link libraries -------------------------------------------------------
target_link_libraries(cugraph_c PRIVATE cugraph::cugraph)

################################################################################
# - generate tests -------------------------------------------------------------

if(BUILD_TESTS)
  include(CTest)
  add_subdirectory(tests)
endif()

################################################################################
# - install targets ------------------------------------------------------------
set(libdir $${CMAKE_CURRENT_BINARY_DIR})
include(CPack)

install(TARGETS cugraph
        DESTINATION ${lib_dir}
        )

install(DIRECTORY include/cugraph/
        DESTINATION include/cugraph)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/include/cugraph/version_config.hpp
        DESTINATION include/cugraph)

install(TARGETS cugraph_c
        DESTINATION ${lib_dir}
        )

install(DIRECTORY include/cugraph_c/
        DESTINATION include/cugraph_c)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/include/cugraph_c/version_config.hpp
        DESTINATION include/cugraph_c)

################################################################################
# - install export -------------------------------------------------------------

set(doc_string
[=[
Provide targets for cuGraph.

cuGraph library is a collection of GPU accelerated graph algorithms that process data found in
[GPU DataFrames](https://github.com/rapidsai/cudf).

]=])

#rapids_export(INSTALL cugraph
#    EXPORT_SET cugraph-exports
#    GLOBAL_TARGETS cugraph cugraph_c
#    NAMESPACE cugraph::
#    DOCUMENTATION doc_string
#    )

################################################################################
# - build export ---------------------------------------------------------------
#rapids_export(BUILD cugraph
#    EXPORT_SET cugraph-exports
#    GLOBAL_TARGETS cugraph cugraph_c
#    NAMESPACE cugraph::
#    DOCUMENTATION doc_string
#    )

################################################################################
# - make documentation ---------------------------------------------------------
# requires doxygen and graphviz to be installed
# from build directory, run make docs_cugraph

# doc targets for cugraph
find_package(Doxygen 1.8.11)
if(Doxygen_FOUND)
    add_custom_command(OUTPUT CUGRAPH_DOXYGEN
                       WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/doxygen
                       COMMAND ${CMAKE_COMMAND} -E env "RAPIDS_VERSION_MAJOR_MINOR=${RAPIDS_VERSION_MAJOR_MINOR}" doxygen Doxyfile
                       VERBATIM)

    add_custom_target(docs_cugraph DEPENDS CUGRAPH_DOXYGEN)
endif()

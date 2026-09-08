# Knowledge Graph Visualizer with radio button search options and optimized for millions of records
"""
Performance Optimizations for Large-Scale Graphs (Millions of Records):
"""
import streamlit as st
import pandas as pd
import os

# Page configuration
st.set_page_config(
    page_title="Knowledge Graph Visualizer",
    page_icon="🕸️",
    layout="wide"
)

# Get Snowflake session
conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

# Set role to access the database
try:
    session = conn.session()
    session.sql("USE ROLE SFLK_GBU_A01A0E_DEVELOPER_DEV").collect()
except Exception as e:
    st.warning(f"Graph Visualisation not availble")

# Database and schema
DB_SCHEMA = "A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY"

# Title and description
st.title("🕸️ Knowledge Graph Visualizer")
st.markdown("Explore and analyze the graph ontology data with advanced search and network analytics")

# Graph Summary Statistics (displayed on first load)
st.header("Graph Summary Statistics")

# Cache the summary statistics to avoid repeated queries
@st.cache_data(ttl=600)  # Cache for 10 minutes
def get_graph_summary():
    """Fetch summary statistics for the knowledge graph"""
    summary_query = f"""
    WITH node_stats AS (
        SELECT 
            COUNT(*) as total_nodes,
            COUNT(DISTINCT NODE_TYPE) as unique_node_types
        FROM {DB_SCHEMA}.KG_NODE
    ),
    edge_stats AS (
        SELECT 
            COUNT(*) as total_edges,
            COUNT(DISTINCT EDGE_TYPE) as unique_edge_types
        FROM {DB_SCHEMA}.KG_EDGE
    ),
    degree_stats AS (
        SELECT 
            MAX(degree_count) as max_degree,
            MIN(degree_count) as min_degree
        FROM (
            SELECT SRC_ID as node_id, COUNT(*) as degree_count
            FROM {DB_SCHEMA}.KG_EDGE
            GROUP BY SRC_ID
            UNION ALL
            SELECT DST_ID as node_id, COUNT(*) as degree_count
            FROM {DB_SCHEMA}.KG_EDGE
            GROUP BY DST_ID
        ) combined_degrees
    )
    SELECT 
        n.total_nodes,
        e.total_edges,
        n.unique_node_types,
        e.unique_edge_types,
        d.min_degree,
        d.max_degree
    FROM node_stats n
    CROSS JOIN edge_stats e
    CROSS JOIN degree_stats d
    """
    return conn.query(summary_query)

try:
    with st.spinner("Loading graph statistics..."):
        summary_df = get_graph_summary()
        
        if not summary_df.empty:
            # Display metrics in columns
            col1, col2, col3 = st.columns(3)
            col4, col5, col6 = st.columns(3)
            
            with col1:
                st.metric("Total Nodes", f"{summary_df['TOTAL_NODES'].iloc[0]:,}")
            with col2:
                st.metric("Total Edges", f"{summary_df['TOTAL_EDGES'].iloc[0]:,}")
            with col3:
                st.metric("Unique Node Types", f"{summary_df['UNIQUE_NODE_TYPES'].iloc[0]:,}")
            with col4:
                st.metric("Unique Edge Types", f"{summary_df['UNIQUE_EDGE_TYPES'].iloc[0]:,}")
            with col5:
                st.metric("Min Degree", f"{summary_df['MIN_DEGREE'].iloc[0]:,}")
            with col6:
                st.metric("Max Degree", f"{summary_df['MAX_DEGREE'].iloc[0]:,}")
            
except Exception as e:
    st.error(f"Error loading graph statistics: {str(e)}")

st.markdown("---")

# Sidebar for search options  
st.sidebar.header("Search Options")

search_mode = st.sidebar.radio(
    "Select Search Mode",
    ["Search by Node ID", "Ego Network", "Node Type Filter", "Path Finding"],
    index=0,
    key="search_mode_radio"
)

# Initialize session state for storing results
if 'nodes_df' not in st.session_state:
    st.session_state.nodes_df = None
if 'edges_df' not in st.session_state:
    st.session_state.edges_df = None

# Search Mode: Search by Node ID
if search_mode == "Search by Node ID":
    st.sidebar.markdown("---")
    node_id = st.sidebar.text_input("Enter Node ID", "")
    
    if st.sidebar.button("Search"):
        if node_id:
            with st.spinner("Searching..."):
                # Optimized: Single query to get node and its neighbors
                combined_query = f"""
                WITH target_node AS (
                    SELECT NODE_ID, NODE_TYPE, NAME, PROPS, TS_INGESTED
                    FROM {DB_SCHEMA}.KG_NODE
                    WHERE NODE_ID = '{node_id}'
                ),
                connected_nodes AS (
                    SELECT DISTINCT 
                        CASE 
                            WHEN SRC_ID = '{node_id}' THEN DST_ID
                            ELSE SRC_ID
                        END AS NODE_ID
                    FROM {DB_SCHEMA}.KG_EDGE
                    WHERE SRC_ID = '{node_id}' OR DST_ID = '{node_id}'
                ),
                all_nodes AS (
                    SELECT * FROM target_node
                    UNION ALL
                    SELECT n.NODE_ID, n.NODE_TYPE, n.NAME, n.PROPS, n.TS_INGESTED
                    FROM {DB_SCHEMA}.KG_NODE n
                    INNER JOIN connected_nodes c ON n.NODE_ID = c.NODE_ID
                )
                SELECT * FROM all_nodes
                """
                nodes = conn.query(combined_query)
                
                # Get connected edges - optimized with indexed columns
                edge_query = f"""
                SELECT EDGE_ID, EDGE_TYPE, SRC_ID, DST_ID, WEIGHT, PROPS
                FROM {DB_SCHEMA}.KG_EDGE
                WHERE (SRC_ID = '{node_id}' OR DST_ID = '{node_id}')
                """
                edges = conn.query(edge_query)
                
                st.session_state.nodes_df = nodes
                st.session_state.edges_df = edges
        else:
            st.sidebar.warning("Please enter a Node ID")

# Search Mode: Ego Network
elif search_mode == "Ego Network":
    st.sidebar.markdown("---")
    node_id = st.sidebar.text_input("Enter Center Node ID", "")
    hops = st.sidebar.slider("Number of Hops", 1, 3, 1)
    
    if st.sidebar.button("Generate Ego Network"):
        if node_id:
            hop_text = str(hops) + "-hop"
            spinner_msg = "Generating " + hop_text + " ego network..."
            with st.spinner(spinner_msg):
                if hops == 1:
                    # Optimized 1-hop: Use UNION ALL instead of UNION for better performance, add LIMIT
                    nodes_query = f"""
                    WITH ego_nodes AS (
                        SELECT SRC_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE DST_ID = '{node_id}'
                        UNION ALL
                        SELECT DST_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE SRC_ID = '{node_id}'
                        UNION ALL
                        SELECT '{node_id}' AS NODE_ID
                    ),
                    unique_nodes AS (
                        SELECT DISTINCT NODE_ID FROM ego_nodes
                    )
                    SELECT n.NODE_ID, n.NODE_TYPE, n.NAME, n.PROPS, n.TS_INGESTED
                    FROM {DB_SCHEMA}.KG_NODE n
                    INNER JOIN unique_nodes e ON n.NODE_ID = e.NODE_ID
                    LIMIT 5000
                    """
                    
                    edges_query = f"""
                    WITH ego_nodes AS (
                        SELECT SRC_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE DST_ID = '{node_id}'
                        UNION ALL
                        SELECT DST_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE SRC_ID = '{node_id}'
                        UNION ALL
                        SELECT '{node_id}' AS NODE_ID
                    ),
                    unique_nodes AS (
                        SELECT DISTINCT NODE_ID FROM ego_nodes
                    )
                    SELECT e.EDGE_ID, e.EDGE_TYPE, e.SRC_ID, e.DST_ID, e.WEIGHT, e.PROPS
                    FROM {DB_SCHEMA}.KG_EDGE e
                    INNER JOIN unique_nodes src ON e.SRC_ID = src.NODE_ID
                    INNER JOIN unique_nodes dst ON e.DST_ID = dst.NODE_ID
                    LIMIT 10000
                    """
                    
                elif hops == 2:
                    # Optimized 2-hop: Better indexing with INNER JOIN and LIMIT
                    nodes_query = f"""
                    WITH hop1 AS (
                        SELECT SRC_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE DST_ID = '{node_id}'
                        UNION ALL
                        SELECT DST_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE SRC_ID = '{node_id}'
                    ),
                    hop1_distinct AS (
                        SELECT DISTINCT NODE_ID FROM hop1
                    ),
                    hop2 AS (
                        SELECT e.SRC_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop1_distinct h ON e.DST_ID = h.NODE_ID
                        UNION ALL
                        SELECT e.DST_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop1_distinct h ON e.SRC_ID = h.NODE_ID
                    ),
                    all_nodes AS (
                        SELECT NODE_ID FROM hop1_distinct
                        UNION ALL
                        SELECT DISTINCT NODE_ID FROM hop2
                        UNION ALL
                        SELECT '{node_id}' AS NODE_ID
                    )
                    SELECT n.NODE_ID, n.NODE_TYPE, n.NAME, n.PROPS, n.TS_INGESTED
                    FROM {DB_SCHEMA}.KG_NODE n
                    INNER JOIN (SELECT DISTINCT NODE_ID FROM all_nodes) a ON n.NODE_ID = a.NODE_ID
                    LIMIT 5000
                    """
                    
                    edges_query = f"""
                    WITH hop1 AS (
                        SELECT SRC_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE DST_ID = '{node_id}'
                        UNION ALL
                        SELECT DST_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE SRC_ID = '{node_id}'
                    ),
                    hop1_distinct AS (
                        SELECT DISTINCT NODE_ID FROM hop1
                    ),
                    hop2 AS (
                        SELECT e.SRC_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop1_distinct h ON e.DST_ID = h.NODE_ID
                        UNION ALL
                        SELECT e.DST_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop1_distinct h ON e.SRC_ID = h.NODE_ID
                    ),
                    all_nodes AS (
                        SELECT NODE_ID FROM hop1_distinct
                        UNION ALL
                        SELECT DISTINCT NODE_ID FROM hop2
                        UNION ALL
                        SELECT '{node_id}' AS NODE_ID
                    ),
                    unique_all_nodes AS (
                        SELECT DISTINCT NODE_ID FROM all_nodes
                    )
                    SELECT e.EDGE_ID, e.EDGE_TYPE, e.SRC_ID, e.DST_ID, e.WEIGHT, e.PROPS
                    FROM {DB_SCHEMA}.KG_EDGE e
                    INNER JOIN unique_all_nodes src ON e.SRC_ID = src.NODE_ID
                    INNER JOIN unique_all_nodes dst ON e.DST_ID = dst.NODE_ID
                    LIMIT 10000
                    """
                    
                else:  # hops == 3
                    # Optimized 3-hop with LIMIT to prevent excessive data retrieval
                    nodes_query = f"""
                    WITH hop1 AS (
                        SELECT SRC_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE DST_ID = '{node_id}'
                        UNION ALL
                        SELECT DST_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE SRC_ID = '{node_id}'
                    ),
                    hop1_distinct AS (
                        SELECT DISTINCT NODE_ID FROM hop1
                    ),
                    hop2 AS (
                        SELECT e.SRC_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop1_distinct h ON e.DST_ID = h.NODE_ID
                        UNION ALL
                        SELECT e.DST_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop1_distinct h ON e.SRC_ID = h.NODE_ID
                    ),
                    hop2_distinct AS (
                        SELECT DISTINCT NODE_ID FROM hop2
                    ),
                    hop3 AS (
                        SELECT e.SRC_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop2_distinct h ON e.DST_ID = h.NODE_ID
                        UNION ALL
                        SELECT e.DST_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop2_distinct h ON e.SRC_ID = h.NODE_ID
                    ),
                    all_nodes AS (
                        SELECT NODE_ID FROM hop1_distinct
                        UNION ALL
                        SELECT NODE_ID FROM hop2_distinct
                        UNION ALL
                        SELECT DISTINCT NODE_ID FROM hop3
                        UNION ALL
                        SELECT '{node_id}' AS NODE_ID
                    )
                    SELECT n.NODE_ID, n.NODE_TYPE, n.NAME, n.PROPS, n.TS_INGESTED
                    FROM {DB_SCHEMA}.KG_NODE n
                    INNER JOIN (SELECT DISTINCT NODE_ID FROM all_nodes) a ON n.NODE_ID = a.NODE_ID
                    LIMIT 5000
                    """
                    
                    edges_query = f"""
                    WITH hop1 AS (
                        SELECT SRC_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE DST_ID = '{node_id}'
                        UNION ALL
                        SELECT DST_ID AS NODE_ID FROM {DB_SCHEMA}.KG_EDGE WHERE SRC_ID = '{node_id}'
                    ),
                    hop1_distinct AS (
                        SELECT DISTINCT NODE_ID FROM hop1
                    ),
                    hop2 AS (
                        SELECT e.SRC_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop1_distinct h ON e.DST_ID = h.NODE_ID
                        UNION ALL
                        SELECT e.DST_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop1_distinct h ON e.SRC_ID = h.NODE_ID
                    ),
                    hop2_distinct AS (
                        SELECT DISTINCT NODE_ID FROM hop2
                    ),
                    hop3 AS (
                        SELECT e.SRC_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop2_distinct h ON e.DST_ID = h.NODE_ID
                        UNION ALL
                        SELECT e.DST_ID AS NODE_ID 
                        FROM {DB_SCHEMA}.KG_EDGE e
                        INNER JOIN hop2_distinct h ON e.SRC_ID = h.NODE_ID
                    ),
                    all_nodes AS (
                        SELECT NODE_ID FROM hop1_distinct
                        UNION ALL
                        SELECT NODE_ID FROM hop2_distinct
                        UNION ALL
                        SELECT DISTINCT NODE_ID FROM hop3
                        UNION ALL
                        SELECT '{node_id}' AS NODE_ID
                    ),
                    unique_all_nodes AS (
                        SELECT DISTINCT NODE_ID FROM all_nodes
                    )
                    SELECT e.EDGE_ID, e.EDGE_TYPE, e.SRC_ID, e.DST_ID, e.WEIGHT, e.PROPS
                    FROM {DB_SCHEMA}.KG_EDGE e
                    INNER JOIN unique_all_nodes src ON e.SRC_ID = src.NODE_ID
                    INNER JOIN unique_all_nodes dst ON e.DST_ID = dst.NODE_ID
                    LIMIT 10000
                    """
                
                nodes = conn.query(nodes_query)
                edges = conn.query(edges_query)
                
                st.session_state.nodes_df = nodes
                st.session_state.edges_df = edges
        else:
            st.sidebar.warning("Please enter a Node ID")

# Search Mode: Node Type Filter
elif search_mode == "Node Type Filter":
    st.sidebar.markdown("---")
    # Get available node types with caching
    @st.cache_data(ttl=600)  # Cache for 10 minutes
    def get_node_types():
        node_types_query = f"""
        SELECT DISTINCT NODE_TYPE
        FROM {DB_SCHEMA}.KG_NODE
        ORDER BY NODE_TYPE
        """
        return conn.query(node_types_query)['NODE_TYPE'].tolist()
    
    try:
        node_types = get_node_types()
        
        selected_type = st.sidebar.selectbox("Select Node Type", node_types)
        limit = st.sidebar.slider("Limit Results", 10, 1000, 100)
        
        if st.sidebar.button("Filter by Type"):
            with st.spinner("Filtering nodes..."):
                # Optimized: Use LIMIT and only fetch edges between filtered nodes
                nodes_query = f"""
                SELECT NODE_ID, NODE_TYPE, NAME, PROPS, TS_INGESTED
                FROM {DB_SCHEMA}.KG_NODE
                WHERE NODE_TYPE = '{selected_type}'
                LIMIT {limit}
                """
                nodes = conn.query(nodes_query)
                
                # Optimized: Only get edges if we have nodes
                if not nodes.empty:
                    node_ids = "','".join(nodes['NODE_ID'].astype(str).tolist())
                    edges_query = f"""
                    SELECT EDGE_ID, EDGE_TYPE, SRC_ID, DST_ID, WEIGHT, PROPS
                    FROM {DB_SCHEMA}.KG_EDGE
                    WHERE SRC_ID IN ('{node_ids}')
                      AND DST_ID IN ('{node_ids}')
                    """
                    edges = conn.query(edges_query)
                else:
                    edges = pd.DataFrame()
                
                st.session_state.nodes_df = nodes
                st.session_state.edges_df = edges
    except Exception as e:
        st.sidebar.error(f"Error fetching node types: {e}")

# Search Mode: Path Finding
elif search_mode == "Path Finding":
    st.sidebar.markdown("---")
    source_id = st.sidebar.text_input("Source Node ID", "")
    target_id = st.sidebar.text_input("Target Node ID", "")
    max_depth = st.sidebar.slider("Max Path Depth", 1, 5, 3)
    max_paths = st.sidebar.slider("Max Paths to Return", 10, 100, 50)
    
    if st.sidebar.button("Find Paths"):
        if source_id and target_id:
            with st.spinner("Finding paths..."):
                # Optimized: Bidirectional BFS with early termination and strict limits
                paths_query = f"""
                WITH RECURSIVE paths AS (
                    -- Base case: start from source
                    SELECT 
                        SRC_ID,
                        DST_ID,
                        EDGE_TYPE,
                        ARRAY_CONSTRUCT(SRC_ID, DST_ID) AS path_nodes,
                        ARRAY_CONSTRUCT(EDGE_TYPE) AS path_edges,
                        1 AS depth
                    FROM {DB_SCHEMA}.KG_EDGE
                    WHERE SRC_ID = '{source_id}'
                      AND DST_ID != '{source_id}'
                    LIMIT 1000  -- Limit initial fan-out
                    
                    UNION ALL
                    
                    -- Recursive case: extend paths with cycle prevention
                    SELECT 
                        e.SRC_ID,
                        e.DST_ID,
                        e.EDGE_TYPE,
                        ARRAY_APPEND(p.path_nodes, e.DST_ID) AS path_nodes,
                        ARRAY_APPEND(p.path_edges, e.EDGE_TYPE) AS path_edges,
                        p.depth + 1 AS depth
                    FROM {DB_SCHEMA}.KG_EDGE e
                    INNER JOIN paths p ON e.SRC_ID = p.DST_ID
                    WHERE p.depth < {max_depth}
                      AND e.DST_ID != '{source_id}'
                      AND NOT ARRAY_CONTAINS(e.DST_ID::VARIANT, p.path_nodes)
                      AND ARRAY_SIZE(p.path_nodes) < 20  -- Hard limit on path length
                ),
                target_paths AS (
                    SELECT 
                        path_nodes,
                        path_edges,
                        depth
                    FROM paths
                    WHERE DST_ID = '{target_id}'
                    QUALIFY ROW_NUMBER() OVER (ORDER BY depth, ARRAY_SIZE(path_nodes)) <= {max_paths}
                )
                SELECT * FROM target_paths
                ORDER BY depth, ARRAY_SIZE(path_nodes)
                """
                
                try:
                    paths_result = conn.query(paths_query)
                    
                    if not paths_result.empty:
                        # Optimized: Collect unique nodes and edges efficiently
                        all_nodes_set = set()
                        edge_pairs = set()
                        
                        for _, row in paths_result.iterrows():
                            path_nodes = row['PATH_NODES']
                            if isinstance(path_nodes, str):
                                import json
                                path_nodes = json.loads(path_nodes)
                            all_nodes_set.update(path_nodes)
                            
                            # Create edge pairs from path
                            for i in range(len(path_nodes) - 1):
                                edge_pairs.add((str(path_nodes[i]), str(path_nodes[i+1])))
                        
                        # Optimized: Batch fetch node details with limit
                        if len(all_nodes_set) > 5000:
                            st.warning(f"Path contains {len(all_nodes_set)} nodes. Limiting to 5000 for display.")
                            all_nodes_set = set(list(all_nodes_set)[:5000])
                        
                        node_ids = "','".join(str(n) for n in all_nodes_set)
                        nodes_query = f"""
                        SELECT NODE_ID, NODE_TYPE, NAME, PROPS, TS_INGESTED
                        FROM {DB_SCHEMA}.KG_NODE
                        WHERE NODE_ID IN ('{node_ids}')
                        """
                        nodes = conn.query(nodes_query)
                        
                        # Optimized: Batch fetch edges with indexed columns
                        if len(edge_pairs) > 10000:
                            st.warning(f"Path contains {len(edge_pairs)} edges. Limiting to 10000 for display.")
                            edge_pairs = set(list(edge_pairs)[:10000])
                        
                        # Build optimized edge query using UNION ALL for index utilization
                        edge_queries = [f"SELECT EDGE_ID, EDGE_TYPE, SRC_ID, DST_ID, WEIGHT, PROPS FROM {DB_SCHEMA}.KG_EDGE WHERE SRC_ID = '{src}' AND DST_ID = '{dst}'" 
                                       for src, dst in edge_pairs]
                        edges_query = " UNION ALL ".join(edge_queries[:10000])  # Hard limit
                        edges = conn.query(edges_query)
                        
                        st.session_state.nodes_df = nodes
                        st.session_state.edges_df = edges
                        
                        # Display path statistics
                        st.info(f"✓ Found {len(paths_result)} path(s) | {len(all_nodes_set)} nodes | {len(edge_pairs)} edges | Shortest: {paths_result['DEPTH'].min()} hops")
                    else:
                        st.warning(f"No paths found from {source_id} to {target_id} within {max_depth} hops")
                        st.session_state.nodes_df = None
                        st.session_state.edges_df = None
                        
                except Exception as e:
                    st.error(f"Error finding paths: {e}")
                    st.session_state.nodes_df = None
                    st.session_state.edges_df = None
        else:
            st.sidebar.warning("Please enter both Source and Target Node IDs")

# Display results
if st.session_state.nodes_df is not None and not st.session_state.nodes_df.empty:
    
    # Summary metrics
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.metric("Total Nodes", len(st.session_state.nodes_df))
    with col2:
        st.metric("Total Edges", len(st.session_state.edges_df) if st.session_state.edges_df is not None else 0)
    with col3:
        if not st.session_state.nodes_df.empty:
            unique_types = st.session_state.nodes_df['NODE_TYPE'].nunique()
            st.metric("Node Types", unique_types)
    with col4:
        # Calculate memory usage
        nodes_memory = st.session_state.nodes_df.memory_usage(deep=True).sum() / 1024 / 1024
        edges_memory = st.session_state.edges_df.memory_usage(deep=True).sum() / 1024 / 1024 if st.session_state.edges_df is not None else 0
        total_memory = nodes_memory + edges_memory
        st.metric("Data Size", f"{total_memory:.1f} MB")
    
    # Tabs for different views
    tab1, tab2, tab3, tab4 = st.tabs(["Data Tables", "Analytics", "Node Details", "Network Stats"])
    
    with tab1:
        # Optimized: Pagination for large datasets
        st.header("Nodes")
        
        # Pagination controls
        rows_per_page = st.select_slider(
            "Rows per page",
            options=[50, 100, 500, 1000, 5000],
            value=100
        )
        
        total_nodes = len(st.session_state.nodes_df)
        total_pages = (total_nodes - 1) // rows_per_page + 1
        
        if total_pages > 1:
            page_num = st.number_input(
                f"Page (1-{total_pages})",
                min_value=1,
                max_value=total_pages,
                value=1
            )
            start_idx = (page_num - 1) * rows_per_page
            end_idx = min(start_idx + rows_per_page, total_nodes)
            st.caption(f"Showing rows {start_idx + 1} to {end_idx} of {total_nodes}")
            
            # Display paginated data
            st.dataframe(
                st.session_state.nodes_df.iloc[start_idx:end_idx],
                use_container_width=True,
                height=400
            )
        else:
            st.dataframe(st.session_state.nodes_df, use_container_width=True, height=400)
        
        # Download button for full dataset
        if total_nodes > 0:
            csv = st.session_state.nodes_df.to_csv(index=False).encode('utf-8')
            st.download_button(
                label="Download Nodes CSV",
                data=csv,
                file_name="nodes_export.csv",
                mime="text/csv"
            )
        
        # Edges with pagination
        if st.session_state.edges_df is not None and not st.session_state.edges_df.empty:
            st.header("Edges")
            
            total_edges = len(st.session_state.edges_df)
            total_edge_pages = (total_edges - 1) // rows_per_page + 1
            
            if total_edge_pages > 1:
                edge_page_num = st.number_input(
                    f"Edge Page (1-{total_edge_pages})",
                    min_value=1,
                    max_value=total_edge_pages,
                    value=1,
                    key="edge_page"
                )
                edge_start_idx = (edge_page_num - 1) * rows_per_page
                edge_end_idx = min(edge_start_idx + rows_per_page, total_edges)
                st.caption(f"Showing rows {edge_start_idx + 1} to {edge_end_idx} of {total_edges}")
                
                st.dataframe(
                    st.session_state.edges_df.iloc[edge_start_idx:edge_end_idx],
                    use_container_width=True,
                    height=400
                )
            else:
                st.dataframe(st.session_state.edges_df, use_container_width=True, height=400)
            
            # Download button for edges
            if total_edges > 0:
                edges_csv = st.session_state.edges_df.to_csv(index=False).encode('utf-8')
                st.download_button(
                    label="📥 Download Edges CSV",
                    data=edges_csv,
                    file_name="edges_export.csv",
                    mime="text/csv"
                )
    
    with tab2:
        st.header("Node Type Distribution")
        if not st.session_state.nodes_df.empty:
            # Optimized: Use value_counts which is more efficient than groupby
            type_counts = st.session_state.nodes_df['NODE_TYPE'].value_counts().reset_index()
            type_counts.columns = ['Node Type', 'Count']
            
            # Display as bar chart using Streamlit native
            st.bar_chart(type_counts.set_index('Node Type'))
            
            # Also show the data table
            st.dataframe(type_counts, use_container_width=True)
        
        if st.session_state.edges_df is not None and not st.session_state.edges_df.empty:
            st.header("Edge Type Distribution")
            edge_type_counts = st.session_state.edges_df['EDGE_TYPE'].value_counts().reset_index()
            edge_type_counts.columns = ['Edge Type', 'Count']
            
            # Display as bar chart using Streamlit native
            st.bar_chart(edge_type_counts.set_index('Edge Type'))
            
            # Also show the data table
            st.dataframe(edge_type_counts, use_container_width=True)
    
    with tab3:
        st.header("Detailed Node Information")
        
        if not st.session_state.nodes_df.empty:
            # Optimized: Add search capability for large datasets
            if len(st.session_state.nodes_df) > 100:
                search_term = st.text_input("Search Node ID or Name", "")
                if search_term:
                    filtered_nodes = st.session_state.nodes_df[
                        st.session_state.nodes_df['NODE_ID'].astype(str).str.contains(search_term, case=False) |
                        st.session_state.nodes_df['NAME'].astype(str).str.contains(search_term, case=False)
                    ]
                    node_options = filtered_nodes['NODE_ID'].tolist()
                else:
                    node_options = st.session_state.nodes_df['NODE_ID'].head(1000).tolist()
                    if len(st.session_state.nodes_df) > 1000:
                        st.caption("Showing first 1000 nodes. Use search to find specific nodes.")
            else:
                node_options = st.session_state.nodes_df['NODE_ID'].tolist()
            
            if node_options:
                node_select = st.selectbox(
                    "Select a node to view details",
                    node_options
                )
                
                node_details = st.session_state.nodes_df[st.session_state.nodes_df['NODE_ID'] == node_select].iloc[0]
                
                col1, col2 = st.columns(2)
                with col1:
                    st.subheader("Basic Information")
                    st.write(f"**Node ID:** {node_details['NODE_ID']}")
                    st.write(f"**Node Type:** {node_details['NODE_TYPE']}")
                    st.write(f"**Name:** {node_details['NAME']}")
                    st.write(f"**Ingested:** {node_details['TS_INGESTED']}")
                
                with col2:
                    st.subheader("Properties")
                    if pd.notna(node_details['PROPS']):
                        st.json(node_details['PROPS'])
                    else:
                        st.write("No properties available")
                
                # Show connected edges
                if st.session_state.edges_df is not None and not st.session_state.edges_df.empty:
                    st.subheader("Connected Edges")
                    connected_edges = st.session_state.edges_df[
                        (st.session_state.edges_df['SRC_ID'] == node_select) |
                        (st.session_state.edges_df['DST_ID'] == node_select)
                    ]
                    st.dataframe(connected_edges, use_container_width=True)
    
    with tab4:
        st.header("Network Statistics")
        
        # Calculate degree statistics
        if st.session_state.edges_df is not None and not st.session_state.edges_df.empty:
            # Optimized: Use groupby with efficient aggregation
            in_degree = st.session_state.edges_df['DST_ID'].value_counts().reset_index()
            in_degree.columns = ['NODE_ID', 'in_degree']
            
            out_degree = st.session_state.edges_df['SRC_ID'].value_counts().reset_index()
            out_degree.columns = ['NODE_ID', 'out_degree']
            
            # Merge degrees efficiently
            degree_df = st.session_state.nodes_df[['NODE_ID', 'NODE_TYPE', 'NAME']].merge(
                in_degree,
                on='NODE_ID',
                how='left'
            ).merge(
                out_degree,
                on='NODE_ID',
                how='left'
            )
            
            # Fill NaN with 0 and calculate total
            degree_df['in_degree'] = degree_df['in_degree'].fillna(0).astype(int)
            degree_df['out_degree'] = degree_df['out_degree'].fillna(0).astype(int)
            degree_df['total_degree'] = degree_df['in_degree'] + degree_df['out_degree']
            
            # Display summary statistics
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Avg Degree", f"{degree_df['total_degree'].mean():.2f}")
            with col2:
                st.metric("Max Degree", degree_df['total_degree'].max())
            with col3:
                st.metric("Min Degree", degree_df['total_degree'].min())
            
            # Display top nodes table
            st.subheader("Top 20 Most Connected Nodes")
            top_nodes_table = degree_df.nlargest(20, 'total_degree')
            st.dataframe(top_nodes_table, use_container_width=True)
            
            # Visualize top 10 nodes using bar chart
            st.subheader("Top 10 Most Connected Nodes (Visual)")
            top_nodes = degree_df.nlargest(10, 'total_degree')[['NODE_ID', 'in_degree', 'out_degree']]
            top_nodes_display = top_nodes.set_index('NODE_ID')
            st.bar_chart(top_nodes_display)
    
    # Display paths if available (for Path Finding mode)
    if search_mode == "Path Finding" and 'paths_df' in st.session_state and st.session_state.paths_df is not None:
        st.header("Paths Found")
        st.dataframe(st.session_state.paths_df, use_container_width=True)

else:
    st.info("Select a search mode and parameters from the sidebar to explore the knowledge graph")

# Footer
st.markdown("---")
st.markdown("Knowledge Graph Visualizer")

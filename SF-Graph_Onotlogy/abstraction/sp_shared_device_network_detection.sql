-- Stored procedure for shared device network detection on knowledge graph
CREATE OR REPLACE PROCEDURE A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SP_SHARED_DEVICE_NETWORK_DETECTION(
    RESULT_TABLE_NAME VARCHAR DEFAULT 'SHARED_DEVICE_NETWORK_RESULTS',
    MIN_SHARED_USERS INTEGER DEFAULT 2,
    MIN_NETWORK_SIZE INTEGER DEFAULT 3
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'networkx')
HANDLER = 'run_shared_device_detection'
AS
$$
import pandas as pd
import networkx as nx
from collections import defaultdict, Counter
import json

def run_shared_device_detection(session, result_table_name, min_shared_users, min_network_size):
    """
    Main handler for shared device network detection stored procedure.
    Identifies networks of customers/accounts that share devices - potential fraud rings.
    """
    try:
        # Read data from KG_NODE and KG_EDGE tables
        nodes_df = session.table("A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.KG_NODE").to_pandas()
        edges_df = session.table("A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.KG_EDGE").to_pandas()
        
        # Create undirected graph for device sharing analysis
        G = nx.Graph()
        
        # Add nodes with attributes
        for _, row in nodes_df.iterrows():
            G.add_node(row['NODE_ID'], 
                       node_type=row['NODE_TYPE'],
                       name=row['NAME'],
                       props=row['PROPS'])
        
        # Add edges (convert to undirected)
        for _, row in edges_df.iterrows():
            G.add_edge(row['SRC_ID'], 
                       row['DST_ID'],
                       edge_type=row['EDGE_TYPE'],
                       weight=row['WEIGHT'],
                       props=row['PROPS'])
        
        # Find shared device patterns
        shared_device_data = find_shared_device_patterns(G, min_shared_users)
        
        # Build user networks connected by shared devices
        device_networks = build_device_sharing_networks(G, shared_device_data)
        
        # Filter networks by size
        significant_networks = [n for n in device_networks if n['network_size'] >= min_network_size]
        
        # Prepare results for table
        results = []
        
        for network in significant_networks:
            # Calculate risk score based on multiple factors
            risk_score = calculate_network_risk_score(network, G)
            
            result = {
                'NETWORK_ID': network['network_id'],
                'NETWORK_SIZE': network['network_size'],
                'SHARED_DEVICE_COUNT': len(network['shared_devices']),
                'USER_IDS': ','.join(network['user_nodes'][:100]),
                'DEVICE_IDS': ','.join(network['shared_devices'][:100]),
                'USER_TYPES': json.dumps(dict(Counter([G.nodes[n].get('node_type', 'Unknown') 
                                                        for n in network['user_nodes']]))),
                'DEVICE_TYPES': json.dumps(dict(Counter([G.nodes[d].get('node_type', 'Device') 
                                                          for d in network['shared_devices']]))),
                'TOTAL_EDGES': network['total_edges'],
                'DENSITY': round(network['density'], 4),
                'IS_SUSPICIOUS': risk_score >= 30,
                'RISK_SCORE': risk_score,
                'RISK_FLAGS': '|'.join(network['risk_flags']),
                'MAX_DEVICE_SHARING': network['max_device_sharing'],
                'AVG_DEVICE_SHARING': round(network['avg_device_sharing'], 2),
                'CONNECTED_COMPONENTS': network.get('components', 1),
                'CLUSTERING_COEFFICIENT': round(network.get('clustering', 0), 4)
            }
            
            results.append(result)
        
        # Convert to DataFrame
        results_df = pd.DataFrame(results)
        
        # Write results to Snowflake table
        if len(results_df) > 0:
            # Sort by risk score and network size
            results_df = results_df.sort_values(['RISK_SCORE', 'NETWORK_SIZE'], ascending=False)
            
            # Create Snowpark DataFrame
            sp_df = session.create_dataframe(results_df)
            
            # Write to table (overwrite if exists)
            sp_df.write.mode("overwrite").save_as_table(
                f"A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.{result_table_name}"
            )
            
            # Calculate statistics
            suspicious_count = len(results_df[results_df['IS_SUSPICIOUS'] == True])
            high_risk_count = len(results_df[results_df['RISK_SCORE'] >= 50])
            total_users_flagged = sum(results_df['NETWORK_SIZE'])
            total_devices_flagged = sum(results_df['SHARED_DEVICE_COUNT'])
            
            summary = {
                'status': 'SUCCESS',
                'total_nodes': len(nodes_df),
                'total_edges': len(edges_df),
                'shared_device_patterns': len(shared_device_data),
                'device_networks_found': len(device_networks),
                'significant_networks': len(significant_networks),
                'suspicious_networks': suspicious_count,
                'high_risk_networks': high_risk_count,
                'total_users_flagged': total_users_flagged,
                'total_devices_flagged': total_devices_flagged,
                'min_shared_users': min_shared_users,
                'min_network_size': min_network_size,
                'max_network_size': int(results_df['NETWORK_SIZE'].max()),
                'avg_network_size': round(results_df['NETWORK_SIZE'].mean(), 2),
                'max_risk_score': int(results_df['RISK_SCORE'].max()),
                'result_table': f"A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.{result_table_name}",
                'message': f'Shared device network analysis complete. Found {len(significant_networks)} networks with {min_network_size}+ users, {suspicious_count} suspicious.'
            }
            
            return json.dumps(summary, indent=2)
        else:
            return json.dumps({
                'status': 'SUCCESS',
                'message': f'No significant device sharing networks found with min_shared_users={min_shared_users}, min_network_size={min_network_size}',
                'total_nodes': len(nodes_df),
                'total_edges': len(edges_df),
                'shared_device_patterns': len(shared_device_data)
            }, indent=2)
            
    except Exception as e:
        return json.dumps({
            'status': 'ERROR',
            'error': str(e),
            'error_type': type(e).__name__
        }, indent=2)


def find_shared_device_patterns(graph, min_shared_users):
    """
    Find all devices that are shared by multiple users (Customer/Account nodes).
    """
    shared_devices = []
    
    for node in graph.nodes():
        node_data = graph.nodes[node]
        node_type = node_data.get('node_type', '')
        
        # Look for Device nodes
        if 'Device' in node_type or node_type == 'Device':
            # Get all connected users (neighbors)
            neighbors = list(graph.neighbors(node))
            
            # Filter for Customer/Account type nodes
            user_nodes = []
            for neighbor in neighbors:
                neighbor_type = graph.nodes[neighbor].get('node_type', '')
                if neighbor_type in ['Customer', 'Account', 'User', 'Person']:
                    user_nodes.append(neighbor)
            
            # If device is shared by multiple users, record it
            if len(user_nodes) >= min_shared_users:
                shared_devices.append({
                    'device_id': node,
                    'device_name': node_data.get('name'),
                    'device_type': node_type,
                    'user_count': len(user_nodes),
                    'user_nodes': user_nodes
                })
    
    return sorted(shared_devices, key=lambda x: x['user_count'], reverse=True)


def build_device_sharing_networks(graph, shared_device_data):
    """
    Build networks of users connected through shared devices.
    Users are connected if they share one or more devices.
    """
    networks = []
    network_id = 1
    
    # Build a user-to-user graph based on shared devices
    user_network = nx.Graph()
    device_to_users = {}
    
    for device_info in shared_device_data:
        device_id = device_info['device_id']
        users = device_info['user_nodes']
        device_to_users[device_id] = users
        
        # Connect all pairs of users who share this device
        for i in range(len(users)):
            for j in range(i + 1, len(users)):
                user_i = users[i]
                user_j = users[j]
                
                # Add edge or increment weight if exists
                if user_network.has_edge(user_i, user_j):
                    user_network[user_i][user_j]['weight'] += 1
                    user_network[user_i][user_j]['shared_devices'].append(device_id)
                else:
                    user_network.add_edge(user_i, user_j, weight=1, shared_devices=[device_id])
    
    # Find connected components (each is a network)
    if len(user_network.nodes()) > 0:
        components = list(nx.connected_components(user_network))
        
        for component in components:
            component_nodes = list(component)
            
            # Get all devices shared within this network
            network_devices = set()
            for device_id, users in device_to_users.items():
                # If any 2+ users in this component share this device, include it
                shared_count = sum(1 for u in users if u in component)
                if shared_count >= 2:
                    network_devices.add(device_id)
            
            # Calculate network metrics
            subgraph = user_network.subgraph(component)
            edges_in_network = subgraph.number_of_edges()
            
            # Calculate device sharing stats
            device_sharing_counts = []
            for u, v, data in subgraph.edges(data=True):
                device_sharing_counts.append(data['weight'])
            
            max_sharing = max(device_sharing_counts) if device_sharing_counts else 0
            avg_sharing = sum(device_sharing_counts) / len(device_sharing_counts) if device_sharing_counts else 0
            
            # Network density
            n = len(component_nodes)
            max_edges = n * (n - 1) / 2
            density = edges_in_network / max_edges if max_edges > 0 else 0
            
            # Clustering coefficient
            try:
                clustering = nx.average_clustering(subgraph)
            except:
                clustering = 0
            
            # Risk flags
            risk_flags = []
            
            # Flag 1: Large network
            if n >= 5:
                risk_flags.append(f"Large network ({n} users) - potential fraud ring")
            
            # Flag 2: High device sharing
            if max_sharing >= 3:
                risk_flags.append(f"Users sharing {max_sharing} devices - suspicious coordination")
            
            # Flag 3: Dense network
            if density >= 0.5 and n >= 3:
                risk_flags.append(f"Dense network (density={density:.2f}) - tight clustering")
            
            # Flag 4: Many devices
            if len(network_devices) >= 5:
                risk_flags.append(f"Multiple devices ({len(network_devices)}) shared across network")
            
            networks.append({
                'network_id': f'SDN_{network_id:04d}',
                'network_size': n,
                'user_nodes': component_nodes,
                'shared_devices': list(network_devices),
                'total_edges': edges_in_network,
                'density': density,
                'clustering': clustering,
                'max_device_sharing': max_sharing,
                'avg_device_sharing': avg_sharing,
                'components': 1,
                'risk_flags': risk_flags
            })
            
            network_id += 1
    
    return networks


def calculate_network_risk_score(network, graph):
    """
    Calculate risk score for a device sharing network based on multiple factors.
    """
    risk_score = 0
    
    network_size = network['network_size']
    device_count = len(network['shared_devices'])
    density = network['density']
    max_sharing = network['max_device_sharing']
    
    # Factor 1: Network size (larger = riskier)
    if network_size >= 10:
        risk_score += 40
    elif network_size >= 5:
        risk_score += 25
    elif network_size >= 3:
        risk_score += 15
    
    # Factor 2: Number of shared devices
    if device_count >= 10:
        risk_score += 30
    elif device_count >= 5:
        risk_score += 20
    elif device_count >= 3:
        risk_score += 10
    
    # Factor 3: Network density (tighter = riskier)
    if density >= 0.7:
        risk_score += 25
    elif density >= 0.5:
        risk_score += 15
    elif density >= 0.3:
        risk_score += 5
    
    # Factor 4: Maximum device sharing between any pair
    if max_sharing >= 5:
        risk_score += 30
    elif max_sharing >= 3:
        risk_score += 20
    elif max_sharing >= 2:
        risk_score += 10
    
    # Factor 5: Check for diverse node types (accounts, customers, etc.)
    user_types = set()
    for user_node in network['user_nodes']:
        node_type = graph.nodes[user_node].get('node_type')
        if node_type:
            user_types.add(node_type)
    
    if len(user_types) >= 2:
        # Multiple account types sharing devices - more suspicious
        risk_score += 15
    
    return min(risk_score, 100)  # Cap at 100

$$;

-- Grant execute permission to appropriate role
-- GRANT USAGE ON PROCEDURE A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SP_SHARED_DEVICE_NETWORK_DETECTION(VARCHAR, INTEGER, INTEGER) 
--       TO ROLE SFLK_GBU_A01A0E_DEVELOPER_DEV;

-- Example usage:

-- Run shared device network detection with default parameters
-- CALL A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SP_SHARED_DEVICE_NETWORK_DETECTION(
--     'SHARED_DEVICE_NETWORK_RESULTS', 
--     2,  -- min_shared_users (devices shared by at least 2 users)
--     3   -- min_network_size (networks with at least 3 users)
-- );

-- Run with stricter thresholds (larger fraud rings only)
-- CALL A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SP_SHARED_DEVICE_NETWORK_DETECTION(
--     'SHARED_DEVICE_LARGE_RINGS', 
--     3,  -- devices shared by at least 3 users
--     5   -- networks with at least 5 users
-- );

-- Query all device sharing networks:
-- SELECT * 
-- FROM A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SHARED_DEVICE_NETWORK_RESULTS 
-- ORDER BY RISK_SCORE DESC, NETWORK_SIZE DESC;

-- Query only suspicious networks:
-- SELECT NETWORK_ID, NETWORK_SIZE, SHARED_DEVICE_COUNT, RISK_SCORE, RISK_FLAGS
-- FROM A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SHARED_DEVICE_NETWORK_RESULTS 
-- WHERE IS_SUSPICIOUS = TRUE
-- ORDER BY RISK_SCORE DESC;

-- Find large fraud rings (5+ users):
-- SELECT NETWORK_ID, NETWORK_SIZE, SHARED_DEVICE_COUNT, RISK_SCORE, RISK_FLAGS, USER_IDS
-- FROM A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SHARED_DEVICE_NETWORK_RESULTS 
-- WHERE NETWORK_SIZE >= 5
-- ORDER BY NETWORK_SIZE DESC, RISK_SCORE DESC;

-- Find high device sharing (users sharing many devices):
-- SELECT NETWORK_ID, NETWORK_SIZE, SHARED_DEVICE_COUNT, MAX_DEVICE_SHARING, AVG_DEVICE_SHARING, RISK_FLAGS
-- FROM A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SHARED_DEVICE_NETWORK_RESULTS 
-- WHERE MAX_DEVICE_SHARING >= 3
-- ORDER BY MAX_DEVICE_SHARING DESC;

-- Find dense networks (tight clustering):
-- SELECT NETWORK_ID, NETWORK_SIZE, DENSITY, CLUSTERING_COEFFICIENT, RISK_SCORE, RISK_FLAGS
-- FROM A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SHARED_DEVICE_NETWORK_RESULTS 
-- WHERE DENSITY >= 0.5
-- ORDER BY DENSITY DESC;

-- Analyze network statistics:
-- SELECT 
--     COUNT(*) AS TOTAL_NETWORKS,
--     SUM(NETWORK_SIZE) AS TOTAL_USERS_FLAGGED,
--     SUM(SHARED_DEVICE_COUNT) AS TOTAL_DEVICES_FLAGGED,
--     AVG(NETWORK_SIZE) AS AVG_NETWORK_SIZE,
--     MAX(NETWORK_SIZE) AS MAX_NETWORK_SIZE,
--     AVG(RISK_SCORE) AS AVG_RISK_SCORE,
--     SUM(CASE WHEN IS_SUSPICIOUS THEN 1 ELSE 0 END) AS SUSPICIOUS_NETWORKS,
--     SUM(CASE WHEN RISK_SCORE >= 50 THEN 1 ELSE 0 END) AS HIGH_RISK_NETWORKS
-- FROM A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SHARED_DEVICE_NETWORK_RESULTS;

-- Get specific network details:
-- SELECT NETWORK_ID, USER_IDS, DEVICE_IDS, RISK_FLAGS
-- FROM A01A0E_GBU_FINCRIME_POC.GRAPH_ONTOLOGY.SHARED_DEVICE_NETWORK_RESULTS
-- WHERE NETWORK_ID = 'SDN_0001';

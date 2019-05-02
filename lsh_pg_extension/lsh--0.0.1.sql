CREATE OR REPLACE FUNCTION create_lsh_clusters(path text, col_names text) RETURNS text 
AS $$
    import csv
    from LocalitySensitiveHashing import *
    dimension=100 # size of the vectors
    lsh = LocalitySensitiveHashing( 
                   datafile = path,
                   dim = dimension,       # needs modification
                   r = 50,                # number of rows in each band for r-wise AND in each band
                   b = 100,               # number of bands for b-wise OR over all b bands
                   expected_num_of_clusters = 10,
          )
    lsh.get_data_from_csv()
    #lsh.show_data_for_lsh()
    lsh.initialize_hash_store()
    lsh.hash_all_data()
    #lsh.display_contents_of_all_hash_bins_pre_lsh()
    similarity_groups = lsh.lsh_basic_for_neighborhood_clusters()
    #coalesced_similarity_groups = lsh.merge_similarity_groups_with_coalescence( similarity_groups )
    #merged_similarity_groups = lsh.merge_similarity_groups_with_l2norm_sample_based( coalesced_similarity_groups )
    #lsh.write_clusters_to_file( merged_similarity_groups, "clusters.txt" )
    data_dictionary={}
    csv_file=open(path)
    csv_reader=csv.reader(csv_file,delimiter=',')
    for row in csv_reader:
        data_dictionary[row[0]]="".join(row[1:])
    col_names_l=col_names.split(';')

    GD['cluster_representation_tablename']='CLUSTER_REPRESENTATION'
    query="CREATE TABLE "+GD['cluster_representation_tablename']+" ( "
    for col_name in col_names_l[:-1]:
        query=query+col_name+" varchar(255), "
    query=query+col_names_l[-1]+" varchar("+str(dimension)+"), "
    query=query+"cluster_tablename varchar(255) );"
    plpy.execute(query)
    i=0
    for cluster in similarity_groups:
        tablename="CLUSTER_"+str(i)
        query="CREATE TABLE "+tablename+" ( "
        for col_name in col_names_l[:-1]:
            query=query+col_name+" varchar(255), "
        query=query+col_names_l[-1]+" varchar("+str(dimension)+") ); "
        plpy.execute(query)
        for v in cluster:
            col_values=v.split(';') 
            col_vector=data_dictionary[v]
            query="INSERT INTO "+tablename+" ("+", ".join(col_names_l)+") "
            query=query+"VALUES ("+", ".join(col_values)+","+col_vector+");"
            plpy.execute(query)
        # add first element of each cluster as representative element
        query="INSERT INTO "+GD['cluster_representation_tablename']+" ("+", ".join(col_names_l)+",cluster_tablename) "
        query=query+"VALUES ("+", ".join(cluster[0].split(';'))+","+data_dictionary[cluster[0]]+","+tablename+");"
        plpy.execute(query)
        i=i+1
    return GD['cluster_representation_tablename']
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION get_lsh_cluster(input text, feature_colname text) RETURNS text 
AS $$
    query="SELECT dotproduct("+feature_colname+","+text+") AS similarity,cluster_tablename FROM "+GD["cluster_representation_tablename"]+" ORDER BY similarity DESC LIMIT 1"  
    rv=plpy.execute(query)
    cluster_tablename=rv[0]['cluster_tablename']
    query="SELECT * FROM "+cluster_tablename
    cluster_table=plpy.execute(query)
    return cluster_table
$$ LANGUAGE plpython3u;
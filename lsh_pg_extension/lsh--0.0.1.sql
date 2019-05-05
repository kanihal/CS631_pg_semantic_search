CREATE OR REPLACE FUNCTION create_lsh_clusters(tablename text, colname_feature text, coltypes text, dimension integer) RETURNS text 
AS $$
    import csv
    from LocalitySensitiveHashing import *
    query="SELECT * FROM "+tablename
    feature_table=plpy.execute(query)
    nrows=feature_table.nrows()
    exp_clusters=int(0.1*nrows)
    exp_elems_cluster=float(nrows)/exp_clusters
    keys_lshdict=["sample"+str(i%exp_elems_cluster)+"_"+str(i) for i in range(nrows)]
    lsh_dictionary={}
    values_dict=[feature_table[i][colname_feature] for i in range(0,nrows)]
    for i in range(nrows):
        lsh_dictionary[keys_lshdict[i]]=values_dict[i]
    lsh = LocalitySensitiveHashing( 
                   datafile = lsh_dictionary,       # dictionary of [key(sampleid):value(list containing vector values as floats)]
                   dim = dimension,       # needs modification
                   r = 50,                # number of rows in each band for r-wise AND in each band
                   b = 100,               # number of bands for b-wise OR over all b bands
                   expected_num_of_clusters = exp_clusters,
          )
    lsh.get_data()
    #lsh.show_data_for_lsh()
    lsh.initialize_hash_store()
    lsh.hash_all_data()
    #lsh.display_contents_of_all_hash_bins_pre_lsh()
    similarity_groups = lsh.lsh_basic_for_neighborhood_clusters()
    #coalesced_similarity_groups = lsh.merge_similarity_groups_with_coalescence( similarity_groups )
    #merged_similarity_groups = lsh.merge_similarity_groups_with_l2norm_sample_based( coalesced_similarity_groups )
    #lsh.write_clusters_to_file( merged_similarity_groups, "clusters.txt" )
    
    colnames=feature_table.colnames()
    data_dictionary={}
    keys_dict=[";".join([str(feature_table[i][colname]) for colname in colnames.remove(colname_feature)]) for i in range(0,nrows)]
    for i in range(nrows):
        data_dictionary[keys_lshdict[i]]=keys_dict[i]
    colnames.append(colname_feature)
    
    coltypes=coltypes.split(";")
    GD['cluster_representation_tablename']='CLUSTER_REPRESENTATION'
    query="CREATE TABLE "+GD['cluster_representation_tablename']+" ( "
    for i in range(len(colnames)):
        query=query+colnames[i]+" "+coltypes[i]+", "
    query=query+"cluster_tablename varchar(255) );"
    plpy.execute(query)
    i=0
    for cluster in similarity_groups:
        tablename="CLUSTER_"+str(i)
        query="CREATE TABLE "+tablename+" ( "
        for i in range(len(colnames)):
        query=query+colnames[i]+" "+coltypes[i]+", "
        plpy.execute(query)
        for v in cluster:
            col_values=data_dictionary[v].split(';') 
            col_vector="".join(lsh_dictionary[v])
            query="INSERT INTO "+tablename+" ("+", ".join(colnames)+") "
            query=query+"VALUES ("+", ".join(col_values)+","+col_vector+");"
            plpy.execute(query)
        # add first element of each cluster as representative element
        query="INSERT INTO "+GD['cluster_representation_tablename']+" ("+", ".join(colnames)+",cluster_tablename) "
        query=query+"VALUES ("+", ".join(data_dictionary[cluster[0]].split(';'))+","+"".join(lsh_dictionary[cluster[0]])+","+tablename+");"
        plpy.execute(query)
        i=i+1
    return GD['cluster_representation_tablename']
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION get_lsh_cluster(input text, tablename text, feature_colname text) RETURNS text
AS $$
    query="SELECT dotproduct("+feature_colname+","+text+") AS similarity,cluster_tablename FROM "+GD["cluster_representation_tablename"]+" ORDER BY similarity DESC LIMIT 1"  
    rv=plpy.execute(query)
    cluster_tablename=rv[0]['cluster_tablename']
    return cluster_tablename
$$ LANGUAGE plpython3u;
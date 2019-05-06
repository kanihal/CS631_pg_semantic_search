CREATE OR REPLACE FUNCTION create_lsh_clusters(tablename text, colname_feature text, coltypes text,num_clusters integer) RETURNS text 
AS $$
    global tablename, colname_feature, coltypes
    query="SELECT * FROM "+tablename
    plpy.info(query)
    table_=plpy.execute(query)
    nrows=table_.nrows()
    plpy.info(nrows)
    num_clusters=int(0.01*nrows)
    num_clusters=int(num_clusters)
    exp_elems_cluster=int((nrows)/num_clusters)

    ### LSH
    import csv
    import pickle
    
    docids=["sample"+str(i%exp_elems_cluster)+"_"+str(i) for i in range(nrows)]
    vec_dictionary={}
    values_dict=[table_[i][colname_feature] for i in range(0,nrows)]
    dimension=len(values_dict[0])
    for i in range(nrows):
        vec_dictionary[docids[i]]=values_dict[i]
    #plpy.info(vec_dictionary.keys())
    outfile = open("/home/jkl/d.pickle",'wb')
    pickle.dump(vec_dictionary,outfile)

    
    from LocalitySensitiveHashing import LocalitySensitiveHashing
    lsh = LocalitySensitiveHashing( 
                   datafile = vec_dictionary,       # dictionary of [key(sampleid):value(list containing vector values as floats)]
                   dim = dimension,       # needs modification
                   r = 5,                # number of rows in each band for r-wise AND in each band
                   b = 20,               # number of bands for b-wise OR over all b bands
                   expected_num_of_clusters = num_clusters,
    )
    plpy.info("Loading data")
    lsh.get_data_from_csv()
    plpy.info("Done")
    #lsh.show_data_for_lsh()
    lsh.initialize_hash_store()
    lsh.hash_all_data()
    #lsh.display_contents_of_all_hash_bins_pre_lsh()
    clusters = lsh.lsh_basic_for_neighborhood_clusters()
    #coalesced_clusters = lsh.merge_clusters_with_coalescence( clusters )
    #merged_clusters = lsh.merge_clusters_with_l2norm_sample_based( coalesced_clusters )
    #lsh.write_clusters_to_file( merged_clusters, "clusters.txt" )
    outfile = open("/home/jkl/sim_groups.pickle",'wb')
    pickle.dump(clusters,outfile)
    plpy.info("lsh done")




    colnames=table_.colnames()
    colnames.remove(colname_feature)
    plpy.info(colnames)
    docid_other_col_values={}
    other_col_values=[";".join([str(table_[i][colname]) for colname in colnames]) for i in range(0,nrows)]
    plpy.info(other_col_values)
    for i in range(nrows):
        docid_other_col_values[docids[i]]=other_col_values[i]
    colnames.append(colname_feature)
    
    #create repr table
    coltypes=coltypes.split(";")
    GD['cluster_representation_tablename']='CLUSTER_REPR_TABLE'
    query="CREATE TABLE "+GD['cluster_representation_tablename']+" ( "
    for i in range(len(colnames)):
        query=query+colnames[i]+" "+coltypes[i]+", "
    query=query+"cluster_tablename text );"
    plpy.execute(query)


    j=0
    for cluster in clusters: #cluster is a set of doc ids
        #create cluster table
        tablename="CLUSTER_"+str(j)
        query="CREATE TABLE "+tablename+" ( "
        for i in range(len(colnames)):
            query=query+colnames[i]+" "+coltypes[i]+","
        query=query[:-1]
        query=query+");"
        plpy.execute(query)
        plpy.info(">> "+query)

        #adding values to cluster table
        for v in cluster:
            for k in range(len(vec_dictionary[v])):
                vec_dictionary[v][k]=str(vec_dictionary[v][k])
            col_values=docid_other_col_values[v].split(';')
            for k in range(len(col_values)):
                col_values[k]="'"+col_values[k]+"'"
            col_vector="'{"+",".join(vec_dictionary[v])+"}'"
            query="INSERT INTO "+tablename+" ("+", ".join(colnames)+") "
            query=query+"VALUES ("+", ".join(col_values)+","+col_vector+");"
            plpy.execute(query)
            plpy.info("Insert >> "+query)
        

        # add repr vector to repr table
        query="INSERT INTO "+GD['cluster_representation_tablename']+" ("+", ".join(colnames)+",cluster_tablename) "
        t=list(cluster)[0]
        l=docid_other_col_values[t].split(';')
        for k in range(len(l)):
            l[k]="'"+l[k]+"'"
        query=query+"VALUES ("+", ".join(l)+","+"'{"+",".join(vec_dictionary[t])+"}'"+",'"+tablename+"');"
        plpy.info(query)
        plpy.execute(query)
        plpy.info("##"+ query)
        j=j+1

    return GD['cluster_representation_tablename']
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION get_lsh_cluster(input text, tablename text, feature_colname text) RETURNS text
AS $$
    query="SELECT dotproduct("+feature_colname+","+input+") AS similarity,cluster_tablename FROM "+GD["cluster_representation_tablename"]+" ORDER BY similarity DESC LIMIT 1"  
    rv=plpy.execute(query)
    cluster_tablename=rv[0]['cluster_tablename']
    return cluster_tablename
$$ LANGUAGE plpython3u;
CREATE OR REPLACE FUNCTION create_clusters(tablename text, colname_feature text, coltypes text, num_clusters integer) RETURNS text 
AS $$
    global tablename, colname_feature, coltypes, num_clusters
    query="SELECT * FROM "+tablename
    plpy.info(query)
    table_=plpy.execute(query)
    nrows=table_.nrows()
    plpy.info(nrows)
    #num_clusters=int(0.01*nrows)
    #exp_elems_cluster=int((nrows)/num_clusters)
    num_clusters=int(num_clusters)

    ### k-means
    vec_dictionary=[]
    for i in range(len(table_)):
        vec_dictionary.append(table_[0][colname_feature])

    import numpy as np
    import pickle
    feature_matrix=np.array(vec_dictionary)
    
    outfile = open("/home/jkl/f.pickle",'wb')
    pickle.dump(feature_matrix,outfile)

    from nltk.cluster.kmeans import KMeansClusterer
    from nltk.cluster.util import cosine_distance
    from scipy.spatial.distance import cosine
    

    plpy.info(feature_matrix)
    kclusterer = KMeansClusterer(num_clusters, distance=cosine_distance, repeats=100, avoid_empty_clusters=True)
    labels = kclusterer.cluster(feature_matrix, assign_clusters=True)

    GD['kclusterer']=kclusterer
    outfile = open("/home/jkl/kcluster.mdl",'wb')
    pickle.dump(kclusterer,outfile)

    labels = np.asarray(labels)
    #n_clusters_ = len(set(labels)) - (1 if -1 in labels else 0)

    # Find the representatives
    representatives = {}
    clusters=[]
    for label in set(labels):
        ind = np.argwhere(labels == label).reshape(-1, )
        clusters.append(ind)
        cluster_samples = feature_matrix[ind, :]
        # TODO:Calculate their centroid as an average, check if this is correct
        centroid = np.average(cluster_samples, axis=0)
        distances = [cosine(sample_doc, centroid) for sample_doc in cluster_samples]
        # Keep the document closest to the centroid as the representative
        x=np.argsort(distances)
        # Keep the document closest to the centroid as the representative
        representatives[label] = cluster_samples[x , :][0]
        representatives[label] = [ cluster_samples[x, :][0], ind[x[0]] ]

    #for label, doc in representatives.items():
    #    print("Label : %d -- Representative : %s" % (label, str(doc)))


    colnames=table_.colnames()
    colnames.remove(colname_feature)
    plpy.info(colnames)
    docid_other_col_values={}
    other_col_values=[";".join([str(table_[i][colname]) for colname in colnames]) for i in range(0,nrows)]
    plpy.info(other_col_values)
    for i in range(nrows):
        docid_other_col_values[i]=other_col_values[i]
    colnames.append(colname_feature)
    
    #create repr table
    coltypes=coltypes.split(";")
    GD['repr_table_name']='CLUSTER_REPR_TABLE'
    query="CREATE TABLE "+GD['repr_table_name']+" ( "
    for i in range(len(colnames)):
        query=query+colnames[i]+" "+coltypes[i]+", "
    query=query+"cluster_tablename text );"
    plpy.execute(query)


    for j,cluster in enumerate(clusters): #cluster is a set of doc ids
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
        query="INSERT INTO "+GD['repr_table_name']+" ("+", ".join(colnames)+",cluster_tablename) "
        t=list(representatives[j][0])
        for k in range(len(t)):
            t[k]=""+str(t[k])+""
        tt=representatives[j][1]
        l=docid_other_col_values[tt].split(';')
        for k in range(len(l)):
            l[k]="'"+str(l[k])+"'"
        
        query=query+"VALUES ("+", ".join(l)+","+"'{"+",".join(t)+"}'"+",'"+tablename+"');"
        plpy.info(query)
        plpy.execute(query)
        plpy.info("##"+ query)

    return GD['repr_table_name']
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION get_cluster(x real[]) RETURNS text
AS $$
    y=GD['kclusterer'].classify(x) # internally does dot product with centroids
    cluster_tablename="CLUSTER_"+str(int(y))
    return cluster_tablename
$$ LANGUAGE plpython3u;

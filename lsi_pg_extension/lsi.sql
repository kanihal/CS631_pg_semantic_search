CREATE OR REPLACE FUNCTION load_lsi_model(path text) RETURNS text 
AS $$
    import gensim
    GD['lsi_model'] = lsi = gensim.models.LsiModel.load(path)
    return "Model with %d topics and %d terms" % (lsi.num_topics, lsi.num_terms)
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION transform_to_model(txt text[]) RETURNS real[]
AS $$
    from gensim.utils import smart_open, simple_preprocess
    from gensim.parsing.preprocessing import STOPWORDS
    words=[token for token in simple_preprocess(txt) if token not in STOPWORDS]
    lsi = GD['lsi_model']
    bow = lsi.id2word.doc2bow(words)
    return [v for k,v in lsi[bow]]
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION transform_to_model(document text) RETURNS real[]
AS $$
    import re
    from gensim.utils import smart_open, simple_preprocess
    from gensim.parsing.preprocessing import STOPWORDS
    txt = re.sub(r'(?:https?|ftp)://\S+', '', document)
    from gensim import utils
    words=[token for token in simple_preprocess(txt) if token not in STOPWORDS]
    #words = [token.encode('utf8') for token in
    #    utils.tokenize(text, lower=True, errors='ignore')
    #    if 2 <= len(token) <= 15 and not token.startswith('_')
    #]
    
    lsi = GD['lsi_model']
    bow = lsi.id2word.doc2bow(words)
    return [v for k,v in lsi[bow]]
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION "dotproduct" (real[], real[]) 
RETURNS double precision
AS 'MODULE_PATHNAME', 'dotproduct_real' 
LANGUAGE C STRICT IMMUTABLE;



from gensim.utils import smart_open, simple_preprocess
from gensim.corpora.wikicorpus import _extract_pages, filter_wiki
from gensim.parsing.preprocessing import STOPWORDS
import gensim
import pandas as pd
import numpy as np

def tokenize(text):
    try:
        t=[token for token in simple_preprocess(text) if token not in STOPWORDS]
    except:
        t=[]
    return t

df=pd.read_csv("/mnt/a99/d0/jagadeesha/db_ss/articles1.csv")
df2=pd.read_csv("/mnt/a99/d0/jagadeesha/db_ss/articles2.csv")
df3=pd.read_csv("/mnt/a99/d0/jagadeesha/db_ss/articles3.csv")

df["text"]=""
df2["text"]=""
df3["text"]=""

df["text"]=(df["title"]+" "+df["content"]).apply(tokenize)
df2["text"]=(df2["title"]+" "+df2["content"]).apply(tokenize)
df3["text"]=(df3["title"]+" "+df3["content"]).apply(tokenize)


l=[]
for index, row in df.iterrows():
    l.append(row['text'])
for index, row in df2.iterrows():
    l.append(row['text'])
for index, row in df2.iterrows():
    l.append(row['text'])

id2word_news=gensim.corpora.Dictionary(l)
id2word_news.filter_extremes(no_below=10, no_above=0.1)
print(id2word_news)

id2word_news.save("~/news.dict")

l=[]
for index, row in df.iterrows():
    l.append(id2word_news.doc2bow(row['text']))
for index, row in df3.iterrows():
    l.append(id2word_news.doc2bow(row['text']))
for index, row in df3.iterrows():
    l.append(id2word_news.doc2bow(row['text']))

corpus=l
gensim.corpora.MmCorpus.serialize('~/corpus.mm', corpus)

mm_corpus=gensim.corpora.MmCorpus('~/corpus.mm')
print(mm_corpus)

tfidf_model = gensim.models.TfidfModel(mm_corpus, id2word=id2word_news)

lsi_model = gensim.models.LsiModel(tfidf_model[mm_corpus], id2word=id2word_news, num_topics=100)

gensim.corpora.MmCorpus.serialize('~/news_tfidf.mm', tfidf_model[mm_corpus])
gensim.corpora.MmCorpus.serialize('~/news_lsa.mm', lsi_model[tfidf_model[mm_corpus]])

tfidf_corpus = gensim.corpora.MmCorpus('~/news_tfidf.mm')
lsi_corpus = gensim.corpora.MmCorpus('~/news_lsa.mm')

text = "A blood cell, also called a hematocyte, is a cell produced by hematopoiesis and normally found in blood."
bow_vector = id2word_news.doc2bow(tokenize(text))

lsi_vector = lsi_model[tfidf_model[bow_vector]]
print(lsi_vector)

lsi_model.save('~/lsi_news.model')
tfidf_model.save('~/tfidf_news.model')
id2word_news.save('~/news.dictionary')

lsi_model = gensim.models.LsiModel.load('~/lsi_news.model')

txt = "A blood cell, also called a hematocyte, is a cell produced by hematopoiesis and normally found in blood."

words=[token for token in simple_preprocess(txt) if token not in STOPWORDS]
bow = lsi_model.id2word.doc2bow(words)
vec=lsi_model[bow]
print(vec)


# coding: utf-8

# In[28]:


from gensim.utils import smart_open, simple_preprocess
from gensim.corpora.wikicorpus import _extract_pages, filter_wiki
from gensim.parsing.preprocessing import STOPWORDS
import gensim


# In[2]:


import pandas as pd
import numpy as np


# In[27]:


def tokenize(text):
    try:
        t=[token for token in simple_preprocess(text) if token not in STOPWORDS]
    except:
        t=[]
    return t


# In[4]:


df=pd.read_csv("/mnt/a99/d0/jagadeesha/db_ss/articles1.csv")
df2=pd.read_csv("/mnt/a99/d0/jagadeesha/db_ss/articles2.csv")
df3=pd.read_csv("/mnt/a99/d0/jagadeesha/db_ss/articles3.csv")


# In[5]:


df3.head()


# In[35]:


STOPWORDS


# In[6]:


df.info()


# In[7]:


df["text"]=""
df2["text"]=""
df3["text"]=""


# In[8]:


df["text"]=(df["title"]+" "+df["content"]).apply(tokenize)


# In[9]:


df2["text"]=(df2["title"]+" "+df2["content"]).apply(tokenize)


# In[10]:


df3["text"]=(df3["title"]+" "+df3["content"]).apply(tokenize)


# In[11]:


l=[]
for index, row in df.iterrows():
    l.append(row['text'])
for index, row in df2.iterrows():
    l.append(row['text'])
for index, row in df2.iterrows():
    l.append(row['text'])


# In[12]:


id2word_news=gensim.corpora.Dictionary(l)
id2word_news.filter_extremes(no_below=10, no_above=0.1)


# In[13]:


print(id2word_news)


# In[14]:


id2word_news.save("~/news.dict")


# In[15]:


l=[]
for index, row in df.iterrows():
    l.append(id2word_news.doc2bow(row['text']))
for index, row in df3.iterrows():
    l.append(id2word_news.doc2bow(row['text']))
for index, row in df3.iterrows():
    l.append(id2word_news.doc2bow(row['text']))


# In[16]:


corpus=l
gensim.corpora.MmCorpus.serialize('~/corpus.mm', corpus)


# In[17]:


mm_corpus=gensim.corpora.MmCorpus('~/corpus.mm')


# In[18]:


print(mm_corpus)


# In[19]:


tfidf_model = gensim.models.TfidfModel(mm_corpus, id2word=id2word_news)


# In[20]:


lsi_model = gensim.models.LsiModel(tfidf_model[mm_corpus], id2word=id2word_news, num_topics=100)


# In[21]:


gensim.corpora.MmCorpus.serialize('~/news_tfidf.mm', tfidf_model[mm_corpus])
gensim.corpora.MmCorpus.serialize('~/news_lsa.mm', lsi_model[tfidf_model[mm_corpus]])


# In[22]:


tfidf_corpus = gensim.corpora.MmCorpus('~/news_tfidf.mm')
lsi_corpus = gensim.corpora.MmCorpus('~/news_lsa.mm')


# In[23]:


text = "A blood cell, also called a hematocyte, is a cell produced by hematopoiesis and normally found in blood."
bow_vector = id2word_news.doc2bow(tokenize(text))


# In[24]:


lsi_vector = lsi_model[tfidf_model[bow_vector]]
print(lsi_vector)


# In[25]:


lsi_model.save('~/lsi_news.model')
tfidf_model.save('~/tfidf_news.model')
id2word_news.save('~/news.dictionary')


# In[29]:


lsi_model = gensim.models.LsiModel.load('~/lsi_news.model')


# In[30]:


txt = "A blood cell, also called a hematocyte, is a cell produced by hematopoiesis and normally found in blood."
from gensim.utils import smart_open, simple_preprocess
from gensim.parsing.preprocessing import STOPWORDS
words=[token for token in simple_preprocess(txt) if token not in STOPWORDS]


# In[31]:


bow = lsi_model.id2word.doc2bow(words)
vec=lsi_model[bow]


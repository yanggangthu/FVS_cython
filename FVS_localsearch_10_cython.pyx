#This is a code to calculate feedback vertex set for directed graph
#The algorithm is given by "Applying local search to feedback vertex set problem"
#Author of the paper Philippe Galinier, Eunice Lemamou, Mohamed Wassim Bouzidi
#The code mimic the pseudocode given in Page 805 in that paper
#The code is written by Gang Yang, Penn State University


#This code is written in cython using C list as main data structure

import networkx as nx
import random
import math
from cpython cimport array
import array
from libc.stdlib cimport rand, srand, RAND_MAX
from libc.math cimport exp
from libc.time cimport time

#the following two function calculate the position for the candidate given the existing topological ordering S

#get_position_minus return position as just after its numbered in-coming neighbours
#As in the paper, the function return i_minus(v)

cdef int get_position_minus(dict candidate_incoming_neighbour, list S):
  cdef int position = 1
  for x in range(len(S)-1,-1,-1):             #we loop through index from the end as we try to find the largest index of numbered incoming neighbour
    if S[x] in candidate_incoming_neighbour:
      position = x+2                          #2 comes from we need to put candidate after the incoming neighbour and also the position count from 1 instead of 0
      return position
  return position                             #put the candidate in the first position if there is no numbered incoming neighbour


#get_position_plus return position as just before its numbered out-going neighbours
#As in the paper, the function return i_plus(v)

cdef int get_position_plus(dict candidate_outgoing_neighbour, list S):
  cdef int position = 1+len(S)
  for x in range(len(S)):                     #we loop through index from the beginning as we try to find the smallest index of numbered outgoing neighbour
    if S[x] in candidate_outgoing_neighbour:
      position = x+1                          #1 comes from the fact position count from 1 instead of 0
      return position
  return position                             #put the candidate in the first position if there is no numbered outgoing neighbour


#FVS_local_search calcualte the longest sub topological ordering of G_input (directed graph) based on simulated annealing(SA) of local search of topological ordering
#FVS is G_input \ the topological ordering
#T_0 is the initial temperature for the geometric cooling regime in SA
#alpha is the cooling multiplier for temperatue
#maxMvt is the number of iterations for the inner loop given a fixed temperatue
#the program stops when maxFail number of outloops (temperatue) fail to improve the result

def FVS_local_search(G_input,float T_0,float alpha,int maxMvt,int maxFail, randomseed):
  #setup randomseed
  if randomseed==None:
    srand(time(NULL))
  else:
    srand(int(randomseed))
  #set paramaters
  G=G_input.copy()
  cdef int N, i
  N= len(G.nodes())           #number of nodes in the graph
  cdef list edges
  edges=G.edges()


  #Initialization
  cdef float T
  T = T_0                     #set initial temperatue
  cdef int nbFail = 0         #Outer loop counter to record failure times
  cdef list S = []            #list to record the ascending ordering
  cdef list S_optimal = []    #list to record the optimal ordering

  #one can use try/except for candidate_incoming_neighbour/candidate_outgoing_neighbour
  #however, here we kinda assume that we will run over almost every node
  #calculate parent and child node for each node
  cdef list parent = [{} for i in range(N)]
  cdef list child = [{} for i in range(N)]

  for i in range(len(edges)):
    edge=edges[i]
    child[int(edge[0])][int(edge[1])]=None
    parent[int(edge[1])][int(edge[0])]=None

  #print child
  #print parent

  cdef int nbMvt, candidate, position_type, candidate_index, N_unnumbered, N_conflict
  cdef dict candidate_incoming_neighbour,candidate_outgoing_neighbour
  cdef int node, x, position, nodetemp
  cdef list I_minus, I_plus, CV_pos, CV_neg
  cdef list S_trail,S_trail_head,S_trail_tail
  cdef list conflict
  cdef int delta_move
  cdef float prob
  cdef list unnumbered, self_loops


  self_loops = [edges[i][0] for i in range(len(edges)) if edges[i][0]==edges[i][1]]   #all the nodes that are self_loops
  unnumbered=[x for x in range(N) if x not in self_loops]                             #all the nodes that is not in S
  N_unnumbered = len(unnumbered)
  while nbFail< maxFail:
    nbMvt = 0       #Inner loop counter to record movement times
    failure = True  #if cardinal of S increase after one inner loop, failure will be set to false
    while nbMvt < maxMvt:
      candidate_index= rand() % N_unnumbered
      candidate = unnumbered[candidate_index]         #random pick a node from all unnumbered node
      position_type = rand()%2                        #random choose a position type
      #calculate incoming/outgoing neighbour for the candidate node, store as keys in the dict
      candidate_incoming_neighbour = parent[candidate]
      candidate_outgoing_neighbour = child[candidate]
      #see how to find the position on Page 803 of the paper
      #position_type=1 means just after incoming neighbours
      if position_type==1:
        position = get_position_minus(candidate_incoming_neighbour,S)
      #position_type=0 means just before outgoint neighbours
      elif position_type==0:
        position = get_position_plus(candidate_outgoing_neighbour,S)

      #first, insert the candidate to the given position
      S_trail = S[:]  #copy the list
      S_trail.insert(position-1,candidate)

      #second remove all the conflict
      #break the sequence into two parts: before and after the candidate node and
      S_trail_head= S_trail[:position-1]
      S_trail_tail= S_trail[position:]
      #determine conflict node See page 801
      if position_type==1:
        CV_pos=[]    #conflict before the newly inserted node in the topological ordering
        for x in range(len(S_trail_head)):
          nodetemp=S_trail_head[x]
          #print nodetemp,candidate_outgoing_neighbour,nodetemp in candidate_outgoing_neighbour
          if nodetemp in candidate_outgoing_neighbour:
            CV_pos.append(nodetemp)
        conflict=CV_pos   #there won't be conflict after the inserted node as the node inserted after its incoming neighbour
      elif position_type==0:
        CV_neg=[]    #conflict after the newly inserted node in the topological ordering
        for x in range(len(S_trail_tail)):
          nodetemp=S_trail_tail[x]
          #print nodetemp,candidate_incoming_neighbour,nodetemp in candidate_incoming_neighbour
          if nodetemp in candidate_incoming_neighbour:
            CV_neg.append(nodetemp)
        conflict=CV_neg   #there won't be conflict before the inserted node as the node inserted before its outgoing neighbour
      #finally remove the conflict node
      N_conflict=len(conflict)
      if N_conflict>0:
        for i in range(N_conflict):
          S_trail.remove(conflict[i])

      #third, evaluate the move
      #delta_move=-len(S_trail)+len(S)
      delta_move=N_conflict-1
      #print S,S_trail,candidate, position, candidate_incoming_neighbour, candidate_outgoing_neighbour, conflict
      #accept all the move that is not harmful, otherwise use metrospolis algorithm
      if delta_move<=0 or math.exp(-delta_move/float(T))>float(rand())/float(RAND_MAX):
        S = S_trail[:]
        #update unnumbered nodes
        unnumbered.remove(candidate)   #remove the node just inserted
        if N_conflict>0:               #add all the conflict node just removed
          for i in range(N_conflict):
            unnumbered.append(conflict[i])
        N_unnumbered+=delta_move
        nbMvt = nbMvt+1
        #update S_optimal only when there is increase in cardinal of the sequence
        if len(S)>len(S_optimal):
          S_optimal = S[:]
          failure = False
          #print S, conflict, candidate, candidate_incoming_neighbour, candidate_outgoing_neighbour
        if N_unnumbered==0:
          return S_optimal

    #Increment the failure times if no progress in size of the sequence
    if failure==True:
      nbFail+=1
    else:    #otherwise reset the num of failure times
      nbFail=0
    #shrink the temperatue by factor alpha
    T=T*alpha
    #print T
    #print nbFail
  return S_optimal




pgr_aStarTravellingPurchaserProblem
===================================

Compute the shortest route given starting and ending points are given, along with the destinations (McDonald, Bank) one wanna go. This is different from the TSP as there the user doesn't know "WHICH" McDonald or Bank. This function will compute the nearest possible nodes using buffer creation in succession, and then calculate the best possible route using "pgr_aStarFromAtoBviaC" function.

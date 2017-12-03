# Project4 Part I

**Team Members**:
Roukna Sengupta (UFID - 4947 4474), Anuja Salunkhe (UFID - 3213 0171)

**Instructions to run**: 
Step 1: Open an unix terminal and start the tweeter engine by using the following command:
```
$ mix escript.build
$ ./tweeter_simulator_part1
```
Step 2: Once the server is started, note the IP address of the server (It will be displayed on the screen).
Step 3: Open another terminal and run the simulator using the following command:
```
$ mix escript.build
$ ./tweeter_simulator_part1 1000 10.3.1.212
```
where 1000 is the number of users and 10.3.1.212 is the IP address of the server. Enter the *number of users* you wish to run the simulator with. The IP address is the IP address of the server (noted in the previous step). Every time you run the simulator for a different *number of users*, make sure you restart the tweeter engine prior to it (as in Step 1 and Step 2).

**What is working**:
We have developed a Twitter like engine which allows users to register and login. A user can follow other users. User can send tweets. Once a user is online, he/she will get live tweets from the users he/she is subscribed to. The user can retweet some of these tweets. User can also query for tweets containing his mentions or particular hashtags or all tweets of the users he/she is following.

We have taken the *number of users* as user input. Then we have registered all the users with the tweeter engine. Once registered we have subscribed the users as per Zipf distribution. We have assumed that user1 has the highest popularity, user 2 has the second highest popularity, user 3 has the third highest popularity and so one. More popular users will tweets more. We have added delays in between consecutive tweets for each user. The delay allotted for user with more rank is less than the delay for user with less rank, thus, ensuring the popular users tweet more. Some of the tweets are retweeted. Periods of connection and disconnection has been ensured. After certain time intervals, a random number of users are either killed (logged out) or connected (logged in). Once, a user logs in, he/she queries from the tweeter engine all the tweets pertaining to the users he is following. Also, at specific intervals, 5 random users queries for tweets with hashtags and his mentions. 

**Performance**:
We simulated against different number of users and got the following results (tweets/sec):
| Number of users | Number of tweets | Time taken (in secs) | Number of tweets per sec |
|-----------------|------------------|----------------------|--------------------------|
| 100             | 631001           | 30                   | 21033                    |
| 500             | 877635           | 30                   | 29254                    |
| 1000            | 1413243          | 30                   | 35331                    |
| 1500            | 1257037          | 30                   | 41901                    |
| 2000            | 1017682          | 30                   | 33922                    |
| 5000            | 1007331          | 30                   | 33577                    |
|                 |                  |                      |                          |

**What is the maximum number of user you could run your code against**:
We could simulate against a maximum of 5000 users with 33577 tweets per sec.


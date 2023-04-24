2023 Semester 1 COMS3200 Assignment 1 Part C README 
Jamie Katsamatsas
s4674720

    HIGH LEVEL ABSTRACT DETAILING OF MY APPROACH
The primary files for this assignment are chatserver.py and chatclient.py.
The chatserver.py and chatclient.py is a TCP chat server client program 
implemented according to the COMS3200 Assignment 1 Part C spec sheet. 

NOTE: some naming conventions differ between the assignment spec and the submitted implementation.
    - In the submission a Channel is referred to as chat_room
    - In the submission a Channel contains a waiting queue and a chat room

The assignment was designed using OOP and threads. This enabled me to group 
all functionality with the object. Servers, channels, clients, and queues 
were given their own classes and files in order to make my code more 
maintainable and simpler to debug.

Threading was used to handle multiple concurrent channels and client connections.
The server had threads to handle:
    - main thread, spins up all child threads and runs shutdown process
    - channel listener thread, listens for incoming client connections and 
    creates new client objects
    - client thread, listens for incoming messages from clients and adds them 
    to a processing queue
    - logic thread, busy wait loop that handles all server logic i.e. send 
    client messages, process incoming messages, process queue and chat room
    - server input thread, listens for commands from the cli

The client has threads to handle:
    - main thread, handles shutdown
    - incoming message thread, listens for incoming messages from the server
    - logic thread, processes incoming messages/commands
    - client command thread, listens for messages/commands from the user

Auxiliary files required to run the server and client are:
    channel.py - Channel class that contains the channel name, port, capacity, 
    chat_room, client_queue, socket connection to join the channel and a lock 
    to make operations on the channel atomic. The channel methods contains 
    methods that act on the queue and chat room such as moving clients from 
    the queue to the chat room and closing all connections in the channel.

    client_queue.py - represents a client queue which simply extends a python 
    list class with some additional functionality to perform threadsafe 
    adding and removal of clients.

    sender_receiver.py - generic class with two static methods, send_message() 
    and receive_message() which are used by the client and server to send a 
    receive generic messages of any size over TCP.

    server_client.py - client class used by the server to store all information 
    related to the client that the server requires. e.g. mute status, 
    connection sockets, time last active.

    utils.py - utilities module that holds shared generic methods used by 
    any file within this submission.

    LIST OF FUNCTIONS AND DESCRIPTIONS
Docstrings for all functions are included in their respective python files.

    OVERVIEW OF CODE TESTING
Through the development of the assignment as each function was implemented 
individual tests were run against each function to ensure correctness.

Once enough individual functions were written to enable testing of a specific 
functionality listed in the assignment spec this was tested with some 
basic test cases.

Once the entire assignment spec was tested with my rough initial test cases 
the tutor provided test cases were run against the code. Debugging mode was 
turned on and the last line in the test case files that removes the results 
of the test was commented out. This enabled me to compare what output was 
expected to what output was generated. Next the test cases that failed were 
run individually and the server/client comparison/capture files were used 
to see differences and correct mistakes. 

    REFERENCES
[1]     A. Rockikz, "How to Transfer Files in the Network using Sockets in Python." thepythoncode.com. https://www.thepythoncode.com/article/send-receive-files-using-sockets-python (accessed April 5, 2023).
[2]     G. McMillan, "Socket Programming HOWTO" python.org. https://docs.python.org/3/howto/sockets.html (accessed April 5, 2023)
[3]     J. Baker, "socket.shutdown vs socket.close" stackoverflow.com. https://stackoverflow.com/questions/409783/socket-shutdown-vs-socket-close (accessed March 29, 2023).
[4]     J. Xu, "Handling Message Boundary in Socket Programming" enzircle.com. https://enzircle.com/handling-message-boundaries-in-socket-programming (accessed April 10)
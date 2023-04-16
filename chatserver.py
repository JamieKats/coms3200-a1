"""
The University of Queensland
Semester 1 2023 COMS3200 Assignment 1 Part C

author: Jamie Katsamatsas 
student id: 46747200

This file contains the implementation of a server in a server client chat 
program for COMS3200.

Usage: python3 chatserver.py configfile

TODO remove all instances of todo print statements in all files
"""
"""
Each channel is on indenpendent socket
channel name cannot begin with number
at least 3 channels in config
channel capacity at least 5

Clients joining a channel are put into a FIFO queue until there is a free 
position in the channel

QUESTIONS
    - if the channel is not full does the server still send the client the queue
    message saying they are in a queue??
    only send 0 queue msg when channel is full
    - if the channel is full does the queue wait time message get printed every
    time the number of clients ahead reduces???
    yes
    - are we allowed to use json module
    A. if runs on moss then ok
    - if client is half way through typing a message and a message is received 
    from their channel do you just print to stdout which would insert 
    somewhere in the clients typed message
    A person typing message will have their input interupted by the new message
    - if a client moves from one queue to another does their waiting time reset?
    no timer for people in queue, timer only applies to people in channel
    - if user inputs '        this is a message         ' do we send the message
    with the spaces on either side or can we strip the spaces???
    A send full thing. if command has space in front then it is not a valid command
    - is anything displayed to the client when they have ben /kick(ed) by the 
    server?
    A client process just ends, no msg printed for client
    - can we use concurrent.futures.ThreadPoolExecutor() ? is a context manager 
    for threads, will auto handle .join() on all threads in the threadpool
        - https://realpython.com/intro-to-python-threading/
        - https://docs.python.org/3/library/concurrent.futures.html
    If it runs  on moss then OK
    - if the channel is empty but there are multiple people in the queue, 
    should each user be updated as they move through the queue and into the chat
    room or should they only get the message that they have joined the channel
    A multiple people joining queue at same time for an empty channel get the 
    queue messages still. e.g. 50 people joining an empty channel of size 100 
    will get all queue update messages as all the people in front move into the channel
    
    A
    - if someone leaves queue in middle ALL users in queue get queue position msg
    
    
    - how do the qns foir part A work? are they changing everytime you start a new attempt on BB?
    are we also suppose to submit answers on BB or just the solutions we post as the PDF
    - what file types expected to be sent??
    - if a command is provided with invalid commands, what to do?
    - if a command is provided with more or less commands than expected, what to do?
    - if client is starting up and they specify a channel that has someone with same username, what do we do?
    If client swaps channels and someone already exists with the same username we dont move them, 
    but nothing is specified for how we handle this case when the client is starting up for the first time
    - max size of messages sent??
    
    NOTES FOR JAMIE 15/4/23
    - when client exits early (crashes) server crashes because it tries to close pipes for 
    the client that has already died
    - in readme specify that channel is refering to the collection of chat lobby and queue
    - need to handle client having msg piped into client instance immediately,
    therefore need to wait for server connection before actuually taking in input
"""
import socket
import threading
import time
import sys
import json
import queue
import signal
from utils import get_time

from server_client import ServerClient
from client_queue import ClientQueue
from channel import Channel

SERVER_HOST = '127.0.0.1'

MSG_BUFFER_SIZE = 4096

# command line arguments
CONFIG_COMMAND = 1

VALID_CLIENT_COMMANDS = ['/whisper', '/quit', '/list', '/switch', '/send']
VALID_SERVER_COMMANDS = ['/kick', '/mute', '/empty', '/shutdown']

AFK_TIME_LIMIT = 100000 # TODO put back to 100


class ChatServer:
    """
    Implementation of a server in a client server chat application connecting 
    over TCP.
    """
    def __init__(self) -> None:
        # check enough command line arguments given
        if len(sys.argv) != 2:
            exit(1)
        
        config_path = sys.argv[CONFIG_COMMAND]
        
        self.channel_configs = {}
        self.load_config(config_path)
        
        # initialise channels
        self.channels: dict = self.create_channels()
        
        # set signal handler
        signal.signal(signal.SIGINT, self.shutdown) # TODO
        
        # queues used for intra thread communication 
        self.client_message_queue = queue.Queue()        
        self.server_command_queue = queue.Queue()
        
        # threads send message to this queue if the system should shutdown
        self.shutdown_queue = queue.Queue()
        self.shutdown_server = False
        
        
    # TODO two shutdowns temporary, one for sigint one for shutdown command
    def shutdown(self, signum=None, frame=None) -> None:
        """
        Shuts down the server.
        
        Sends shutdown messages to the channels then closes the thread.
        """
        # close all client sockets in queues and channels
        for channel in self.channels.values():
            channel.shutdown()
        
        # exit process
        # time.sleep(1) # TODO tmp sleep aded before exit to allow daemon threads to throw exceptions to fix
        exit(0)
        
        
    def get_clients_channel(self, username: str) -> Channel:
        """
        Returns the channel the client is apart of. None otherwise

        Args:
            username (str): username of the client

        Returns:
            Channel: channel the client is in
        """
        for channel in self.channels.values():
            if channel.get_client_in_channel(username) is not None:
                return channel
            
            
    def get_channel(self, channel_name: str) -> Channel:
        """
        Returns the channel if it exists, None otherwise

        Args:
            channel_name (str): channel name to search for

        Returns:
            Channel: channel if it exists, none otherwise
        """
        for channel in self.channels.values():
            if channel.name == channel_name:
                return channel
        return None
        
        
    def load_config(self, config_path: str) -> None:
        """
        Loads the config given.

        Args:
            config_path (str): the file path of the config file
        """
        try:
            file = open(config_path, "r")
        except OSError:
            exit(1)
            
        # load lines of config into the channel config dictionary
        lines = file.read().splitlines()
        for line in lines:
            config_options = line.split(" ")
            
            if len(config_options) != 4: exit(1)
            
            name = config_options[1]
            
            try:
                port = int(config_options[2])
                capacity = int(config_options[3])
            except ValueError:
                exit(1)
            
            # if channel name already exists exit
            if name in self.channel_configs.keys():
                exit(1)
            
            self.channel_configs[name] = {
                "port": port,
                "capacity": capacity
                }
            
        self.check_channel_config(self.channel_configs)
          
          
    def check_channel_config(self, channel_configs):
        """_summary_

        Args:
            chanel_config (_type_): _description_
        """
        channel_ports = [channel_config["port"] for channel_config in channel_configs.values()]
        if len(channel_ports) != len(set(channel_ports)) \
            or 0 in channel_ports \
            or len(channel_configs) < 3:

            exit(1)
            
        for channel_name, channel_info in self.channel_configs.items():
            if channel_name[0].isdigit(): exit(1)
            if channel_info["capacity"] < 5: exit(1)

    
    def create_channels(self) -> dict:
        """
        Creates the channels from the config dictionary.

        Returns:
            dict: dicitonary of channels mapped to their names
        """
        channels = {}
        for channel_name, channel_info in self.channel_configs.items():
            port = int(channel_info["port"])
            capacity = int(channel_info["capacity"])
            # print(f"chatserver create_channels: port {port}")
            
            # create channel socket and bind
            self.channel_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.channel_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.channel_socket.bind((SERVER_HOST, port))
            self.channel_socket.listen()
            
            channels[channel_name] = Channel(
                name=channel_name,
                port=port,
                capacity=capacity,
                conn_socket=self.channel_socket
            )
            
        return channels
    
            
    def start(self) -> None:
        """
        Starts the threads handling the server logic and communication.
        """
        # create thread to handle user input
        server_command_thread = threading.Thread(
            target=self.server_command_thread, 
            args=(self.server_command_queue, ),
            daemon=True)
        server_command_thread.start()
        
        # create thread to handle all logic processing the channels and 
        # incoming messages
        server_logic_thread = threading.Thread(
            target=self.server_logic_thread,
            args=(self.client_message_queue, self.server_command_queue, self.channels, ),
            daemon=True)
        server_logic_thread.start()
        
        # start up server threads to listen to channel sockets for incoming 
        # connections
        self.start_channel_listeners()
        
        # when a msg sent to shutdown queue, start server shutdown process
        self.shutdown_queue.get(block=True)
        self.shutdown()
         
            
    def server_command_thread(self, server_command_queue: queue.Queue) -> None:
        """
        Handle server commands from the command line.

        Args:
            server_command_queue (queue.Queue): intra thread message queue 
            commands are sent to
        """
        while True:
            try:
                server_command = input().strip().split(" ")
            except EOFError:
                continue
                # return
            
            command = server_command[0]
            args = server_command[1:]
            message = {
                "messsage_type": "server_command",
                "command": command,
                "args": args
            }
            server_command_queue.put(message)
    

    def client_listener_thread(
        self, 
        client: ServerClient, 
        channel: Channel
    ) -> None:
        # if client already exists with same name in channel close new client
        if channel.client_in_channel(client.name):
            message = {
                'message_type': 'basic',
                'message': f"[Server message ({get_time()})] Cannot connect to the {channel.name} channel."
            }
            client.send_message(message)
            client.shutdown(graceful_shutdown=True)
            return

        # add client to channel queue
        channel.add_client_to_queue(client)

        # incoming client message handling loop        
        while True:
            try:
                message = client.receive_message()
            except ConnectionResetError:
                channel.close_client(username=client.name, graceful_shutdown=False)
                # channel.remove_client_from_channel(client.name)
                # client.shutdown()
                return
            
            # None message indicated client socket is closed, remove client
            if message is None:
                channel.close_client(username=client.name, graceful_shutdown=False)
                # channel.remove_client_from_channel(client.name)
                # client.shutdown()
                return
            
            # if message first word is a valid command edit message metadata
            first_word = message["message"].split(" ")[0]
            if first_word in VALID_CLIENT_COMMANDS:
                message["message_type"] = "client_command"
                message["command"] = first_word
                message["args"] = message["message"].split(" ")[1:]
                del message["message"]
                message["file"] = message.get("file", None)
            
            # add client username, and channel port to msg metadata
            message["sender"] = client.name
            message["channel"] = channel

            self.client_message_queue.put(message)
            
    
    def server_logic_thread(
        self, 
        client_message_queue: queue.Queue,
        server_command_queue: queue.Queue,
        channels: dict
        ) -> None:
        """
        Executes the main control loop that handles
            - channel queues
            - incoming client messages/commands
            - incoming server commands
            - checks if users are AFK
        """
        while not self.shutdown_server:
            self.process_channel_queues(channels)

            self.process_client_messages(client_message_queue)

            self.process_server_commands(server_command_queue)
            
            self.check_afk_clients(channels)
            
            # self.send_outgoing_messages()
       
            # add small sleep to slow down busy wait a bit
            time.sleep(0.01)


    def start_channel_listeners(self) -> None:
        """
        Starts the listening threads for all the channels.
        """
        for channel in self.channels.values():
            channel_listener_thread = threading.Thread(
                target=self.channel_listen_thread,
                args=(channel, ),
                daemon=True
            )
            channel_listener_thread.start()


    def channel_listen_thread(self, channel: Channel) -> None:
        """
        Accepts incoming client connection requests and sets up the socket 
        used to communicate further with the client.

        Args:
            channel (Channel): channel to listen for new connections
        """
        while True:
            try:
                # print(channel.conn_socket.getsockname()[1])
                connection_socket, addr = channel.conn_socket.accept()
            except OSError:
                return
            # create client with name=None then fill out later
            client: ServerClient = ServerClient(
                name=None,
                conn_socket=connection_socket,
                addr=addr)
            
            # receive first message from client with clients username
            client_settings = client.receive_message()
            
            client.name = client_settings["username"]
            
            # create listener thread for new user
            client_listener_thread = threading.Thread(
                target=self.client_listener_thread,
                args=(client, channel),
                daemon=True)
            client_listener_thread.start()
            
            
    def process_channel_queues(self, channels: dict) -> None:
        """
        Processes the queues for all the channels.
        
        Moves clients from the queue into the chat room when there is space and
        sends the queue location messages to the clients in the queue.

        Args:
            channels (dict): dictionary of all the channels
        """
        for channel in channels.values():
            # move users from queue to chat lobby if there is space
            users_in_lobby = len(channel.chat_room)
            if users_in_lobby < channel.capacity:
                users_to_add = min(
                    channel.capacity - users_in_lobby, 
                    len(channel.client_queue))
                
                # fill up all free spaces in the chat room with users from the 
                # queue
                for _ in range(0, users_to_add):
                    channel.move_client_to_lobby()
            
        
    def process_client_messages(self, incoming_queue: ClientQueue) -> None:
        """
        Processes incoming client messages and commands.

        Args:
            incoming_queue (ClientQueue): queue all incoming client messages are 
            put in.
        """
        try:
            message = incoming_queue.get(block=False)
        except queue.Empty as e:
            return
        
        client_name = message["sender"]
        channel: Channel = message["channel"]
        client: ServerClient  = channel.get_client_in_channel(client_name)
        
        # reset AFK timer when client sends msg/cmd when not muted
        # print(message)
        # print(client)
        if client.is_muted() == False:
            client.time_last_active = time.time()
            
        # handle client commands
        if message["message_type"] == "client_command":
            self.handle_client_command(message)
            return

        # handle normal client chat messages
        if message["message_type"] == "basic":
            # if msg from user in a queue return early
            if channel.get_client_in_queue(client_name) is not None:
                return
            
            # if client muted dont process message
            if client.is_muted():
                message = {
                    "message_type": "basic",
                    "message": f"[Server message ({get_time()})] You are still muted for {client.remaining_time_muted()} seconds."
                }
                client.send_message(message)
                return
            
            # convert client msg to server formatted msg
            formatted_msg = f"[{client_name} ({get_time()})] {message['message']}"
            print(formatted_msg, flush=True)
            server_msg = {
                'message_type': 'basic',
                'message': formatted_msg
            }
            
            # send message to everyone in chat room
            channel.send_message_clients_in_channel(message=server_msg)
    
    
    def process_server_commands(self, server_command_queue: queue.Queue) -> None:
        """
        Processes incoming server commands.

        Args:
            server_command_queue (queue.Queue): intra thread queue server 
            commands are sent to.
        """
        try:
            message = server_command_queue.get(block=False)
        except queue.Empty:
            return
        
        # ignore invalid server commands
        if message["command"] not in VALID_SERVER_COMMANDS:
            return
        
        self.handle_server_command(message)
        
        
    def check_afk_clients(self, channels: dict) -> None:
        """
        Handles AFK clients.
        
        Any clients that have been inactive for longer than AFK_TIME_LIMIT 
        seconds has their connection closed.

        Args:
            channels (dict): all channels in the server.
        """
        message = {
            "message_type": "basic",
        }
        channel: Channel
        for channel in channels.values():
            client: ServerClient
            for client in channel.chat_room:
                # ignore muted clients
                if client.is_muted(): continue
                
                # remove clients that have exceeded the inacitvity limit
                if client.time_last_active + AFK_TIME_LIMIT < time.time():
                    channel.close_client(username=client.name, graceful_shutdown=True)
                    # channel.remove_client_from_channel(client.name)
                    # client.shutdown()
                    
                    message["message"] = f"[Server message ({get_time()})] {client.name} went AFK."
                    channel.send_message_clients_in_channel(message)
                    print(message["message"], flush=True)
                    
            for client in channel.client_queue:
                # ignore muted clients
                if client.is_muted(): continue
                
                # remove clients that have exceeded the inacitvity limit
                if client.time_last_active + AFK_TIME_LIMIT < time.time():
                    channel.close_client(username=client.name, graceful_shutdown=True)
                    # channel.remove_client_from_channel(client.name)
                    # client.shutdown()
                    
                    message["message"] = f"[Server message ({get_time()})] {client.name} went AFK."
                    channel.send_message_clients_in_channel(message)
                    print(message["message"], flush=True)
                    
                    
    # def send_outgoing_messages()
                
    
    def get_client(self, username: str) -> ServerClient:
        """
        Returns the user object for the username given, if the user doesnt 
        exist in any channels None is returned.

        Args:
            username (str): username of client to return

        Returns:
            ServerClient: the client in the server with the username given. 
            None if they don't exist.
        """
        for channel in self.channels.values():
            # TODO
            # for client in channel.chat_room:
            #     if client.name == username:
            #         return client
            # for client in channel.client_queue:
            #     if client.name == username:
            #         return client
            client: ServerClient = channel.get_client_in_channel(username)
            if client is not None: return client
        return None
    
    
    def handle_client_command(self, message: dict) -> None:
        """
        Processes the client command given.

        Args:
            message (dict): message containing all command metadata.
        """
        command = message["command"]
        if command == '/whisper':
            self.whisper(message)
        elif command == '/quit':
            self.quit(message)
        elif command == '/list':
            self.list(message)
        elif command == '/switch':
            self.switch(message)
        elif command == '/send':
            self.send(message)
                
                
    def whisper(self, received_message: dict) -> None:
        """
        Handles a client whisper command.
        
        When a client whispers the message is sent only to the user specified 
        in the whisper.

        Args:
            received_message (dict): message metadata from the sender.
        """
        client = self.get_client(received_message["sender"])
        
        # if client muted dont process message
        if client.is_muted():
            message = {
                "message_type": "basic",
                "message": f"[Server message ({get_time()})] You are still muted for {client.remaining_time_muted()} seconds."
            }
            client.send_message(message)
            return
            
        args = received_message['args']
        whisper_target = args[0]
        # construct message from args
        whisper_message = " ".join(args[1:])
        target_channel: Channel = received_message["channel"]
        
        # whisper target not in chat lobby
        if target_channel.get_client_in_chat_room(whisper_target) is None:
            no_user_msg = f"[Server message ({get_time()})] {whisper_target} is not here." 
            message = {
                "message_type": "basic",
                "message": no_user_msg,
                "receiver": received_message["sender"]
            }
        # whisper target is in chat lobby
        else:
            formated_whisper = f"[{received_message['sender']} whispers to you: ({get_time()})] {whisper_message}"
            message = {
                "message_type": "basic",
                "message": formated_whisper,
                "receiver": whisper_target
            }
        target_channel.send_message_clients_in_channel(message, message["receiver"])
        
        # print server whisper message
        server_msg = f"[{received_message['sender']} whispers to {whisper_target}: ({get_time()})] {whisper_message}"
        print(server_msg, flush=True)

    
    def quit(self, message: dict) -> None:
        """
        Handles a client quit command.
        
        When a client sends /quit it is signaling to the server to begin 
        shutdown process for that client.

        Args:
            received_message (dict): message metadata from the sender.
        """
        channel: Channel = message["channel"]
        channel.close_client(username=message["sender"], graceful_shutdown=True)
        
        
    def list(self, message: dict) -> None:
        """
        Handles a client list command.
        
        Send a message back to the client containing information about the 
        server channels.

        Args:
            received_message (dict): message metadata from the sender.
        """
        username = message["sender"]
        client: ServerClient = self.get_client(username)
        
        for channel in self.channels.values():
            channel_msg = f"[Channel] {channel.name} {len(channel.chat_room)}/{channel.capacity}/{len(channel.client_queue)}."
            message = {
                "message_type": "basic",
                "message": channel_msg
            }
            client.send_message(message)
            
        
    def switch(self, message: dict) -> None:
        """
        Handles a client switch command.
        
        Disconnects the client from the current channel, then the client 
        reconnects in the new channel.

        Args:
            received_message (dict): message metadata from the sender.
        """
        args = message["args"]
        new_channel_name = args[0]
        new_channel: Channel = self.get_channel(new_channel_name)
        sender_username = message["sender"]
        sender: ServerClient = self.get_client(sender_username)
        
        # if channel doesnt exist tell user and return early
        if new_channel is None:
            message = {
                "message_type": 'basic',
                "message": f"[Server message ({get_time()})] {new_channel_name} does not exist."
            }
            sender.send_message(message)
            return
        
        # If user with same name already exists in new channel, send error to 
        # sender and return early
        existing_client = new_channel.get_client_in_channel(sender_username)
        if existing_client is not None:
            message = {
                "message_type": "basic",
                "message": f"[Server message ({get_time()})] Cannot switch to the {new_channel_name} channel."
            }
            sender.send_message(message)
            return
        
        # remove sender from existing channel
        current_channel: Channel = message["channel"]
        current_channel.remove_client_from_channel(sender_username)
        
        message = {
            "message_type": "basic",
            "message": f"[Server message ({get_time()})] {sender_username} has left the channel."
        }
        
        sender.send_message(message)
        print(message["message"], flush=True)
        
        # send client msg to close socket and reconnect on new port then close 
        # client connection
        sender.switch_channel([new_channel.port])
        
    
    def send(self, message: dict) -> None:
        """
        Handles a client send command.
        
        Sends a file from one client to another.

        Args:
            received_message (dict): message metadata from the sender.
        """
        target_client = message["args"][0]
        file_path = message["args"][1]
        channel: Channel = self.get_clients_channel(message["sender"])
        reply_message = {
            "message_type": "basic",
        }
        
        # the target client is not in the senders channel
        if channel.client_in_channel(target_client) == False:
            reply_message["message"] = f"[Server message ({get_time()})] {target_client} is not here."
            channel.send_message_clients_in_channel(reply_message, message["sender"])
            return
        
        # the file path does not exist
        if message["file"] == b'':
            reply_message["message"] = f"[Server message ({get_time()})] {file_path} does not exist."
            channel.send_message_clients_in_channel(reply_message, message["sender"])
            return

        # send success message to sender        
        reply_message["message"] = f"[Server message ({get_time()})] You sent {file_path} to {target_client}."
        channel.send_message_clients_in_channel(reply_message, message["sender"])
        
        # print server message
        print(f"[Server message ({get_time()})] {message['sender']} sent {file_path} to {target_client}.", flush=True)
        
        # send msg with file
        del message["channel"] # remove "channel" key so json dumps doesnt fail
        channel.send_message_clients_in_channel(message, target_client)
        
    
    def handle_server_command(self, message: dict) -> None:
        """
        Processes the server command given.

        Args:
            message (dict): message containing all command metadata.
        """
        command = message["command"]
        args = message["args"]
        
        if command == "/kick":
            self.kick(args)
        elif command == "/mute":
            self.mute(args)
        elif command == "/empty":
            self.empty(args)
        elif command == "/shutdown":
            self.shutdown_queue.put(1)
            
            
    def kick(self, args: list) -> None:
        """
        Kicks the client from the channel.

        Args:
            args (list): command line arguments given with kick command
        """
        channel_name = args[0].split(":")[0]
        username = args[0].split(":")[1]
        channel: Channel = self.get_channel(channel_name)
        
        # channel doesnt exist
        if channel is None:
            print(f"[Server message ({get_time()})] {channel_name} does not exist.", flush=True)
            return
        
        # client not in specified channel
        if channel.client_in_channel(username) == False:
            print(f"[Server message ({get_time()})] {username} is not in {channel_name}.", flush=True)
            return

        # close connection with client
        channel.close_client(username=username, graceful_shutdown=True)
        # client: ServerClient = channel.get_client_in_channel(username)
        # channel.remove_client_from_channel(username)
        # client.shutdown()
        
        message = {
            "message_type": "basic",
            "message": f"[Server message ({get_time()})] {username} has left the channel."
        }
        channel.send_message_clients_in_channel(message)

        # print server message        
        print(f"[Server message ({get_time()})] Kicked {username}.", flush=True)
        

    def mute(self, args: list) -> None:
        """
        Mutes the client in the channel given.

        Args:
            args (list): command line arguments given with mute command
        """
        channel_name = args[0].split(":")[0]
        username = args[0].split(":")[1]
        time_muted = args[1]
        
        # time must be positive integer
        try:
            time_muted = int(time_muted)
            if time_muted < 1: raise Exception
        except Exception:
            print(f"[Server message ({get_time()})] Invalid mute time.", flush=True)
            return
        
        # user or channel doesnt exist
        if self.get_channel(channel_name) is None or self.get_client(username) is None:
            print(f"[Server message ({get_time()})] {username} is not here.", flush=True)
            return
            
        # user exists and time is valid
        client = self.get_client(username)
        client.mute(time_muted)
        print(f"[Server message ({get_time()})] Muted {username} for {time} seconds.", flush=True)
        message = {
            "message_type": "basic"
        }
        
        # send mute messages to all clients in the chat room
        channel: Channel = self.get_channel(channel_name)
        for client in channel.chat_room:
            if client.name == username:
                message["message"] = f"[Server message ({get_time()})] You have been muted for {time_muted} seconds."
            else:
                message["message"] = f"[Server message ({get_time()})] {username} has been muted for {time_muted} seconds."
            client.send_message(message)
        
    
    def empty(self, args: list) -> None:
        """
        Closes all connections to the clients in the channel chat lobby.

        Args:
            args (list): command line arguments given with this command
        """
        channel_name = args[0]
        channel: Channel = self.get_channel(channel_name)
        
        # channel doesnt exist
        if channel is None:
            print(f"[Server message ({get_time()})] {channel_name} does not exist.", flush=True)
            return

        # close all clients connection in the chat lobby
        client: ServerClient
        for client in channel.chat_room.copy():
            channel.remove_client_from_channel(client.name)
            client.shutdown(graceful_shutdown=True)
            
        print(f"[Server message ({get_time()})] {channel_name} has been emptied.", flush=True)
    
        
def main():
    server = ChatServer()
    server.start()
        
if __name__ == '__main__':
    main()
        
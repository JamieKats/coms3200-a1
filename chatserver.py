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
"""
import socket
import threading
import time
import sys
import json
import queue
from datetime import datetime
import signal
import os
import concurrent

SERVER_NAME = 'server'
SERVER_PORT = 1234
MSG_BUFFER_SIZE = 4096

CONFIG_COMMAND = 1

# class Message()

def get_time():
        """
        Returns the time in 24 hour hh:mm:ss format
        """
        return datetime.now().strftime("%H:%M:%S")
    

class User:
    def __init__(self, name, port, connectiion_socket, addr) -> None:
        self.name: str = name
        self.port: int = port
        self.connection_socket: socket = connectiion_socket
        self.addr = addr
        self.time_last_message = datetime.now()
        
    def send_message(self, message: dict):
    # def send_message(self, message_type, message):
        # msg = json.dumps({
        #     "message_type": message_type,
        #     "message": message
        # })
        # self.connection_socket.send(msg.encode())
        encoded_msg = json.dumps(message).encode()
        self.connection_socket.send(encoded_msg)
    
    def shutdown(self):
        # https://stackoverflow.com/questions/409783/socket-shutdown-vs-socket-close
        "Sends shutdown message to client and closes socket"
        shutdown_msg = {
            "message_type": "command",
            "command": "/shutdown"
        }
        self.send_message(shutdown_msg)
        self.connection_socket.shutdown(socket.SHUT_RDWR)
        # self.connection_socket.close()
        

class ClientQueue(list):
    def __init__(self) -> None:
        super().__init__()
        self.lock: threading.Lock = threading.Lock()
        
    def put(self, user: User):
        self.lock.acquire()
        self.append(user)
        self.lock.release()
        
    def get(self) -> User:
        self.lock.acquire()
        if len(self) == 0:
            return None
        user: User = self.pop(0)
        self.send_waiting_queue_location_message()
        self.lock.release()
        return user
        
    def remove_user(self, user):
        """_summary_
        take lock and dequque to temporary queue, dont add removed user from queue
        and send users behing them new message of how mnay people there is infront
        of them

        Args:
            username (_type_): _description_
        """
        self.lock.acquire()
        self.remove(user)
        self.send_waiting_queue_location_message()
        self.lock.release()

    
    def send_waiting_queue_location_message(self):
        """
        Sends the location message for all clients in the queue
        """
        for i, user in enumerate(self):
            user_location = i + 1
            queue_loc_msg = f"[Server message ({get_time()})] You are in the \
                queue and there are {user_location} user(s) ahead of you."
            message = {
                'message_type': 'basic',
                'message': queue_loc_msg
            }
            user.send_message(message, user)

    
class Channel:
    def __init__(self, name, port, max_users) -> None:
        self.name: str = name
        self.port: int = port
        self.max_users: int = max_users
        self.chat_lobby: list = []
        self.waiting_queue: ClientQueue = ClientQueue()
        
    def add_waiting_user(self, user: User):
        self.waiting_queue.put(user)
        welcome_msg = f"[Server message ({get_time()})] Welcome to the {self.name} channel, {user.name}."
        message = {
            'message_type': 'basic',
            'message': welcome_msg
        }
        user.send_message(message)
        
    def move_user_to_lobby(self):
        # if noone in wating queue return early
        if len(self.waiting_queue) == 0:
            return
        
        # get next user and add to chat lobby
        user = self.waiting_queue.get()
        self.chat_lobby.append(user)
        
        # send <username> joined message to everyone in channel
        join_message = f"[Server message ({get_time()})] {user.name} has joined the channel."
        message = {
            "message_type": 'basic',
            'message': join_message
        }
        self.send_message(message)
        
        # print user joined message to servers stdout
        server_msg = f"[Server message ({get_time()})] {user.name} has joined the {self.name} channel."
        print(server_msg)
        
        
    def send_message(self, message, user=None):
        """
        Sends the message to all users in the channel is user=None,
        otherwise the message is sent to the user specified.
        """
        if user is not None:
            # send message to user
            for user in self.chat_lobby:
                if user.name == user.name:
                    user.send_message(message)
            return
        
        for user in self.chat_lobby:
            user.send_message(message)
            
    def shutdown(self):
        """
        Send shutdown message to all clients in queue and chat lobby, and 
        close sockets

        Returns:
            _type_: _description_
        """
        for client in self.waiting_queue:
            client.shutdown()
        
        for client in self.chat_lobby:
            client.shutdown()
            

class Server:
    def __init__(self) -> None:
        """
        One thread listens for incomming connections
        One thread created for every client connection
        One thread to handle stdin input
        """
        config_path = sys.argv[CONFIG_COMMAND]
        
        self.channel_configs = {}
        self.load_config(config_path)
        
        # initialise channels
        self.channels: dict = self.create_channels()
        
        self.threads = []
        
        # set up listening socket
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.bind(("localhost", SERVER_PORT))
        self.server_socket.listen()
    
        # set signal handler
        signal.signal(signal.SIGINT, self.shutdown)
        
        # queue for messages from server command/client messages to buisness logic thread
        self.incoming_queue = queue.Queue()
        
        self.shutdown_server = False
        
        # threads send message to this queue if the system should shutdown
        self.shutdown_queue = queue.Queue()
        
        
    # NOTE two shutdowns temporary, one for sigint one for shutdown command
    def shutdown(self, signum=None, frame=None):
        print("in shutdwon")
        # close all client sockets in queues and channels
        for channel in self.channels.values():
            channel.shutdown()
        
        # close bind socket
        self.server_socket.close()
        
        # close command daemon thread
        
        
        # exit process
        print("at exit")
        exit()
        
    # def shutdown(self, signum, frame):
    #     # close all client sockets in queues and channels
    #     for channel in self.channels.values():
    #         channel.shutdown()
        
    #     # close bind socket
    #     self.server_socket.close()
        
    #     # close command daemon thread
        
        
    #     # exit process
    #     exit()
        
    def load_config(self, config_path):
        try:
            file = open(config_path, "r")
        except OSError as e:
            print("REMOVE WHEN DONE: config file failed to open...")
            exit(1)
            
        lines = file.read().splitlines()
        for line in lines:
            config_options = line.split(" ")
            port = int(config_options[2])
            name = config_options[1]
            max_users = config_options[3]
            
            self.channel_configs[port] = {
                "name": name,
                "max_users": max_users
                }
          
    
    def create_channels(self) -> dict:
        """
        server needs to know
        
            - channel name
            - channel port
            - list of users
            - channel capacity
        """
        channels = {}
        for channel_port, channel_info in self.channel_configs.items():
            
            channels[channel_port] = Channel(
                name=channel_info["name"],
                port=int(channel_port),
                max_users=int(channel_info["max_users"]),
            )
        return channels
    
    # def create_channel_queues(self, channels):
    #     queues = {}
        
    #     for channel in channels:
    #         queues
        
            
            
    def start(self):
        """
        Accept client connection
        
        add client to channel queue
        
        start client thread to handle connection from then on
        
        wait for next connection
        """
        # create daeomon thread to listen for server commands
        server_command_thread = threading.Thread(
            target=self.server_command_thread, 
            args=(self.incoming_queue, ), 
            daemon=True)
        server_command_thread.start()
        
        # create thread to process channel queues, and execute logic when a 
        # client msg or server command is received
        server_logic_thread = threading.Thread(
            target=self.server_logic_thread,
            args=(self.incoming_queue, self.channels, ),
            daemon=True)
        self.threads.append(server_logic_thread)
        server_logic_thread.start()
        
        # with concurrent.futures.ThreadPoolExecutor() as exetuor:
        
        server_listen_thread = threading.Thread(
            target=self.server_listen_thread,
            # args=,
            daemon=True
        )
        server_listen_thread.start()
        
        # when a msg sent to shutdown queue, start server shutdown process
        self.shutdown_queue.get(block=True)
        self.shutdown()
        
        
        # while True:
        #     # accept new connection and create User
        #     connection_socket, addr = self.server_socket.accept()
        #     client_settings = connection_socket.recv(MSG_BUFFER_SIZE).decode()
        #     client_settings = json.loads(client_settings)
        #     client = User(
        #         name=client_settings["username"],
        #         port=client_settings["port"],
        #         connectiion_socket=connection_socket,
        #         addr=addr)
            
        #     # create listener thread for new user
        #     client_listener_thread = threading.Thread(
        #         target=self.client_listener_thread, 
        #         args=(self.channels, client,), 
        #         daemon=True)
        #     self.threads.append(client_listener_thread)
        #     client_listener_thread.start()
            
    def server_listen_thread(self):
        while True:
            # accept new connection and create User
            connection_socket, addr = self.server_socket.accept()
            client_settings = connection_socket.recv(MSG_BUFFER_SIZE).decode()
            client_settings = json.loads(client_settings)
            client = User(
                name=client_settings["username"],
                port=client_settings["port"],
                connectiion_socket=connection_socket,
                addr=addr)
            
            # create listener thread for new user
            client_listener_thread = threading.Thread(
                target=self.client_listener_thread, 
                args=(self.channels, client,), 
                daemon=True)
            self.threads.append(client_listener_thread)
            client_listener_thread.start()
        
            
            
    def server_command_thread(self, incoming_queue: queue.Queue):
        while True:
            server_command = input().strip()
            message = {
                "messsage_type": "command",
                "message": server_command
            }
            incoming_queue.put(message)
            
            if message["message"] == "/shutdown":
                # self.shutdown_server = True
                # self.shutdown()
                self.shutdown_queue.put(1)
                return
            # print("in command thread")
            # time.sleep(1)
    
            
    def client_listener_thread(self, channels: dict[Channel], client: User):
        # add client to channel queue
        channel: Channel = channels[int(client.port)]
        channel.add_waiting_user(client)
        
        # send client welcome message
        # welcome_msg = f"[Server message ({self.get_time()})] Welcome to the {channel.name} channel, {client.name}."
        # client.send_message("basic", welcome_msg)
        # print(f"Client {client.name} started thread")
        
        while True:
            message = client.connection_socket.recv(MSG_BUFFER_SIZE)
            
            # return if empty message received indicating closed socket
            if message == b'':
                return
            message = json.loads(message.decode())
            # add client username, and channel port to msg metadata
            message["sender"] = client.name
            message["port"] = channel.port
            
            self.incoming_queue.put(message)
            
    
    def server_logic_thread(self, incoming_message_queue, channels):
        """
            - Loop over queues and push new clients into channels + send queue update
            messages to clients
            
            - loop over all users and kick out if timer > AFK time
        
            - receive messages from client listeners and process messages (can be normal
            chat message or a command)
        
            - receive server commands and process them
            
        If a shutdown command received then set flag and exit thread
        """
        while not self.shutdown_server:
            self.process_channel_queues(channels)

            self.process_client_messages(incoming_message_queue, channels)
            
            self.process_server_commands(incoming_message_queue, channels)
       
            time.sleep(0.01)
            
            
    def process_channel_queues(self, channels):
        for channel in channels.values():
            users_in_lobby = len(channel.chat_lobby)
            if users_in_lobby < channel.max_users:
                # print("IN PROCESS CHANNEL QUEUES")
                users_to_add = min(
                    channel.max_users - users_in_lobby, 
                    len(channel.waiting_queue))
                
                for i in range(0, users_to_add):
                    channel.move_user_to_lobby()
                    
            
        
    def process_client_messages(self, incoming_queue: ClientQueue, channels: dict):
        """
        TODO: maybe set up so all messages in queue are processed and only 
        return when no msgs in queue

        Args:
            incoming_queue (ClientQueue): _description_
            channels (dict): _description_
        """
        try:
            message = incoming_queue.get(block=False)
        except queue.Empty as e:
            return
        
        
        # incoming client msg can be command or normal msg
        
        # if normal msg
        # TODO befor this 'if' need to check if client is muted or not
        if message["message_type"] == "basic":
            # convert client msg to server formatted msg
            formatted_msg = f"[{message['sender']} ({get_time()})] {message['message']}"
            print(formatted_msg)
            server_msg = {
                'message_type': 'basic',
                'message': formatted_msg
            }
            
            channel = channels[message["port"]]
            for user in channel.chat_lobby:
                if user.name != message["sender"]:
                    user.send_message(server_msg)
    
    
    def process_server_commands(self, incoming_queue, channels):
        pass
        
        
def main():
    server = Server()
    server.start()
        
if __name__ == '__main__':
    main()
        
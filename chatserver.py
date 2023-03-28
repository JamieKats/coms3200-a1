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
    - if the channel is full does the queue wait time message get printed every
    time the number of clients ahead reduces???
    - are we allowed to use json module
    - if client is half way through typing a message and a message is received 
    from their channel do you just print to stdout which would insert 
    somewhere in the clients typed message
    - if a client moves from one queue to another does their waiting time reset?
    - if user inputs '        this is a message         ' do we send the message
    with the spaces on either side or can we strip the spaces???
    - is anything displayed to the client when they have ben /kick(ed) by the 
    server?
    - can we use concurrent.futures.ThreadPoolExecutor() ? is a context manager 
    for threads, will auto handle .join() on all threads in the threadpool
        - https://realpython.com/intro-to-python-threading/
        - https://docs.python.org/3/library/concurrent.futures.html
"""
from socket import *
from threading import *
import time
import sys
import json
import queue
from datetime import datetime
import signal
import os
import concurrent

SERVER_NAME = 'server'
SERVER_PORT = 14000
MSG_BUFFER_SIZE = 4096

CONFIG_COMMAND = 1

# class Message()

class User:
    def __init__(self, name, port, connectiion_socket, addr) -> None:
        self.name: str = name
        self.port: int = port
        self.connection_socket: socket = connectiion_socket
        self.addr = addr
        
    def send_message(self, message_type, message):
        msg = json.dumps({
            "message_type": message_type,
            "message": message
        })
        self.connection_socket.send(msg.encode())
    
    def receive_message(self):
        pass

class ClientQueue(queue.Queue):
    def __init__(self, maxsize: int = 0) -> None:
        super().__init__(maxsize)
        self.lock = Lock()
    
    def remove_user(self, username):
        """_summary_
        take lock and dequque to temporary queue, dont add removed user from queue
        and send users behing them new message of how mnay people there is infront
        of them

        Args:
            username (_type_): _description_
        """
        pass

    def queue_user(self, ):
        pass
    
class Channel:
    def __init__(self, name, port, max_users) -> None:
        self.name = name
        self.port = port
        self.max_users = max_users
        self.active_users = []
        self.waiting_queue: ClientQueue = ClientQueue()
        
    def add_user(self, user: User):
        self.waiting_queue.put(user)
        
    
    
    
        

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
        self.channels = self.create_channels()
        
        self.threads = []
        
        # set up listening socket
        self.server_socket = socket(AF_INET, SOCK_STREAM)
        self.server_socket.bind(("localhost", SERVER_PORT))
        self.server_socket.listen()
    
        # set signal handler
        signal.signal(signal.SIGINT, self.shut_down)
        
        # queue for messages from server command/client messages to buisness logic thread
        self.incoming_queue = queue.Queue()
        
        
        
    def shut_down(self):
        # close all network connections
        # for channel in self.channels:
        #     for user in self.
        # # close all threads
        pass
        
    def load_config(self, config_path):
        try:
            file = open(config_path, "r")
        except OSError as e:
            print("REMOVE WHEN DONE: config file failed to open...")
            exit(1)
        lines = file.read().splitlines()
        for line in lines:
            config_options = line.split(" ")
            self.channel_configs[config_options[2]] = {
                "name": config_options[1],
                "max_users": config_options[3]
                }
            
    def get_time(self):
        """
        Returns the time in 24 hour hh:mm:ss format
        """
        return datetime.now().strftime("%H:%M:%S")
            
            
    def create_channels(self):
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
                port=channel_port,
                max_users=channel_info["max_users"],
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
        server_command_thread = Thread(
            target=self.server_command_thread, 
            args=(self.incoming_queue, ), 
            daemon=True)
        server_command_thread.start()
        
        # create thread to process channel queues, and execute logic when a 
        # client msg or server command is received
        server_logic_thread = Thread(
            target=self.server_logic_thread,
            args=(self.incoming_queue, self.channels, ),
            daemon=False)
        self.threads.append(server_logic_thread)
        server_logic_thread.start()
        
        # with concurrent.futures.ThreadPoolExecutor() as exetuor:
        
        
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
            client_listener_thread = Thread(target=self.client_listener_thread, args=(self.channels, client,), daemon=True)
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
    
            
    def client_listener_thread(self, channels: dict[Channel], client: User):
        # add client to channel queue
        print(channels)
        channel: Channel = channels[str(client.port)]
        channel.add_user(client)
        
        # send client welcome message
        welcome_msg = f"[Server message ({self.get_time()})] Welcome to the {channel.name} channel, {client.name}."
        client.send_message("basic", welcome_msg)
        print(f"Client {client.name} started thread")
        
        while True:
            client.connection_socket.recv(MSG_BUFFER_SIZE)
            
    
    def server_logic_thread(self, incoming_queue, channels):
        
        
        
def main():
    server = Server()
    server.start()
        
if __name__ == '__main__':
    main()
        
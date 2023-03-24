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
"""
from socket import *
from threading import *
import time
import sys
import json

SERVER_NAME = 'server'
SERVER_PORT = 12000
MSG_BUFFER_SIZE = 4096

CONFIG_COMMAND = 1

class User:
    def __init__(self, name, connectiion_socket, addr) -> None:
        self.name = name
        self.connection_socket = connectiion_socket
        self.addr = addr

class Channel:
    def __init__(self, name, port, max_users) -> None:
        self.name = name
        self.port = port
        self.max_users = max_users
        self.users = []
        self.queue = []
        
    def queue_user(self, ):
        pass
        

class Server:
    def __init__(self) -> None:
        """
        One thread listens for incomming connections
        One thread created for every client connection
        """
        config_path = sys.argv[CONFIG_COMMAND]
        
        self.channel_configs = {}
        self.load_config(config_path)
        
        # initialise channels
        self.channels = self.create_channels()
        
        # set up listening socket
        self.server_socket = socket(AF_INET, SOCK_STREAM)
        self.server_socket.bind(("localhost", SERVER_PORT))
        self.server_socket.listen()
    
        
    def load_config(self, config_path):
        file = open(config_path, "r")
        lines = file.read().splitlines()
        for line in lines:
            config_options = line.split(" ")
            self.channel_configs[config_options[2]] = {
                "name": config_options[1],
                "max_users": config_options[3]
                }
            
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
            
            
    def start(self):
        """
        Accept client connection
        
        add client to channel queue
        
        start client thread to handle connection from then on
        
        wait for next connection
        """
        while True:
            connection_socket, addr = self.server_socket.accept()
            client_settings = connection_socket.recv(MSG_BUFFER_SIZE).decode()
            client_settings = json.loads(client_settings)
            # client = User()
            # self.channels[client_settings["port"]].add
                
            
            
            
            # print(f"accept connection {connection_socket}, {addr}")
            
            client_thread = Thread(target=self.client_thread, args=(1,))
            
            client_thread.start()
            
            
    def client_thread(self, args):
        while True:
            print(f"in client thread {self.channels}")
            time.sleep(0.5)
            
            
        
        
def main():
    server = Server()
    server.start()
        
if __name__ == '__main__':
    main()
        
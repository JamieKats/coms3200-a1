import socket
import threading
import sys
import json
from datetime import datetime
import time

SERVER_NAME = '127.0.0.1'
SERVER_PORT = 1234

MSG_BUFFER_SIZE = 4096

TCP_SEND_BUFFER_LIMIT = 9

VALID_COMMANDS = ['/whisper', '/quit', '/list', '/switch', '/send']

class Client:
    def __init__(self) -> None:
        # load channel info
        if len(sys.argv) != 3:
            exit(1)
        
        # exit if arguments are malformed
        try:
            self.server_port: int = int(sys.argv[1])
            self.client_username: str = sys.argv[2]
        except:
            exit(1)
            
        self.client_settings = {
            "port": self.server_port,
            "username": self.client_username
        }
        
        self.threads = []
        
        self.time_of_mute = 0 # time mute was applied
        self.mute_length = 0 # seconds of mute
        
        self.exit_program = False

        
    def connect_to_server(self):
        self.client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            self.client_socket.connect((SERVER_NAME, SERVER_PORT))
        except ConnectionRefusedError as e:
            print(f"REMOVE WHEN DONE: server socket connection refused: {e}...")
            exit(1)
        
        
    def start(self):
        """
        main thread does nothing (waits for children to finish)
        child_1
            - handles user input and passes to outgoing queue (daemon)
        child_2
            - checks outgoing queue and sends outgoing messages
            - processes incoming messages:
                - print to screen
                - shut down client (/kick, /empty)
                - switch mute flag (/mute))
            can return when done, needs to be joined with main thread
        """
        self.connect_to_server()
        
        # send client username
        self.client_socket.send(json.dumps(self.client_settings).encode())
        
        time.sleep(5) # block and allow server to send multiple messages at once
        
        # receive welcome message
        # welcome_msg = self.client_socket.recv(MSG_BUFFER_SIZE)
        # # welcome_msg = self.client_socket.recv(1)
        # print(welcome_msg)
        # welcome_msg = json.loads(welcome_msg.decode())
        # print(welcome_msg["message"])
        
        # spin up thread to handle incoming/outgoing message queues
        # input thread is daemon so don't need to put in threads list
        input_thread = threading.Thread(
            target=self.input_thread, 
            args=(self.client_socket, ), 
            daemon=True)
        input_thread.start()
        
        receiver_thread = threading.Thread(
            target=self.receiver_thread, 
            args=(self.client_socket, ),
            daemon=False)
        receiver_thread.start()
        
        receiver_thread.join()
        
        
    def input_thread(self, socket):
        """
        Takes input from user, checks command (valid or invalid), then either 
        tells user invalid input was entered or sends the input to the socket 
        """
        while True:
            user_input = input().strip().split(" ")
            command = user_input[0]
            args = user_input[1:]
            
            if command in VALID_COMMANDS:
                message = {
                    "message_type": "client_command",
                    "command": command,
                    "args": args
                }
                self.send_message(message, socket)
                continue
                
            # input that isnt a command is a message
            message = {
                    "message_type": "basic",
                    "message": user_input
                }
            self.send_message(message, socket)
            
                
    
    # def handle_command(self, command: str):
    #     if command == '/whisper':
    #         self.whisper()
    #     elif command == '/quit':
    #         self.quit()
    #     elif command == '/list':
    #         self.list()
    #     elif command == '/switch':
    #         self.switch()
    #     elif command == '/send':
    #         self.send()
            
    # def whisper(self):
    #     raise NotImplementedError
    
    # def quit(self):
    #     raise NotImplementedError
        
    # def list(self):
    #     raise NotImplementedError
        
    # def switch(self):
    #     raise NotImplementedError
    
    # def send(self):
    #     raise NotImplementedError
        
    def send_message(self, message, socket):
        encoded_message = json.dumps(message).encode()
        socket.send(encoded_message)
        
    def receiver_thread(self, socket: socket):
        """Listens for incoming messages and handles them. If its just a message
        print to screen, if its a command process it.

        server commands that will need client processing,
            - /kick, /empty, /shutdown on server side will be same as client 
            calling /quit (force client to exit gracefully)
            - /mute (set flag in client to tell them they are muted for n secs)

        Args:
            socket (_type_): _description_
        """
        while not self.exit_program:
            # https://docs.python.org/3/howto/sockets.html
            # NOTE recv msg len at start of message then call recv for the exact msg size
            # messages smaller than the max buffer size will need to be received in multiple chunks and put together
            
            msg_length = socket.recv(TCP_SEND_BUFFER_LIMIT).decode()
            encoded_message = socket.recv(int(msg_length))
            
            message = json.loads(encoded_message.decode())
            if message["message_type"] == "command":
                self.handle_server_command(message["command"])
            elif message["message_type"] == "basic":
                print(message["message"])
            
    def handle_server_command(self, command, socket=None):
        # server_exit_commands = ['/shutdown',]
        # print(command)
        
        if command == "/shutdown":
            self.shutdown()
            return
            
            
    def shutdown(self):
        self.exit_program = True
    
    
    # def mute(self, seconds: str, client_socket: socket):
    #     self.time_of_mute = time.time()
    #     self.mute_length = float(seconds)
        # message = ""
        # self.send_message(, client_socket)
    
            
        
        
        
def main():
    client = Client()
    client.start()
    
        
if __name__ == "__main__":
    main()
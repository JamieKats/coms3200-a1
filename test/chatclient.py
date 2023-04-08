import socket
import threading
import sys
import json
import queue
from datetime import datetime
import time
from sender_receiver import SenderReceiver

SERVER_NAME = '127.0.0.1'

# MSG_BUFFER_SIZE = 4096
MAX_MSG_BUFFER_SIZE = 10

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
            # "port": self.server_port,
            "username": self.client_username
        }
        
        self.threads = []
        
        self.time_of_mute = 0 # time mute was applied
        self.mute_length = 0 # seconds of mute
        
        self.shutdown_client = False
        
        # input thread
        # spin up thread to handle incoming/outgoing message queues
        # input thread is daemon so don't need to put in threads list
        input_thread = threading.Thread(
            target=self.input_thread, 
            # args=(, ), 
            daemon=True)
        input_thread.start()
        
        self.shutdown_queue = queue.Queue()

        
    def connect_to_server(self):
        self.client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            self.client_socket.connect((SERVER_NAME, self.server_port))
            print(f"Client connected on port {self.server_port}")
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
        while self.shutdown_client == False:
            self.connect_to_server()
            
            # send client username
            self.client_socket.send(json.dumps(self.client_settings).encode())
            
            receiver_thread = threading.Thread(
                target=self.receiver_thread,
                # args=(self.client_socket, ),
                daemon=True)
            receiver_thread.start()
            receiver_thread.join()
            
            time.sleep(1)
        
        self.shutdown_queue.get(block=True)
        self.shutdown()
        
        # receiver_thread.join()
        
        
    def input_thread(self):
        """
        Takes input from user, checks command (valid or invalid), then either 
        tells user invalid input was entered or sends the input to the socket 
        """
        while True:
            user_input = input().strip()
            
            first_word = user_input.split(" ")[0]
            
            if first_word == "/send":
                filename = user_input.split(" ")[2]
                
                message = {
                    "message_type": "basic",
                    "message": user_input,
                    "file": self.load_file(filename)
                }
                self.send_message(message)
                continue
                
                
            # input that isnt a command is a message
            message = {
                    "message_type": "basic",
                    "message": user_input
                }
            
            self.send_message(message)
            
    
    def load_file(self, filename: str) -> str:
        """
        https://www.thepythoncode.com/article/send-receive-files-using-sockets-python

        Args:
            filename (str): _description_

        Returns:
            str: _description_
        """
        try:
            with open(filename, "rb") as f:
                file_bytes = f.read()
                # print(file_bytes)
                return file_bytes
        except FileNotFoundError:
            return b''
        
        
    def save_file(self, filename, file_bytes) -> None:
        with open(filename, "wb") as f:
            f.write(file_bytes)
        
        
    def send_message(self, message):
        # encoded_message = json.dumps(message).encode()
        # self.client_socket.send(encoded_message)
        SenderReceiver.send_message(message, self.client_socket)
        
        
    def receiver_thread(self):
        """Listens for incoming messages and handles them. If its just a message
        print to screen, if its a command process it.

        server commands that will need client processing,
            - /kick, /empty, /shutdown on server side will be same as client 
            calling /quit (force client to exit gracefully)
            - /mute (set flag in client to tell them they are muted for n secs)

        Args:
            socket (_type_): _description_
        """
        while True:
            # https://docs.python.org/3/howto/sockets.html
            # NOTE recv msg len at start of message then call recv for the exact msg size
            # messages smaller than the max buffer size will need to be received in multiple chunks and put together
            
            # try:
            #     msg_length = self.client_socket.recv(TCP_SEND_BUFFER_LIMIT).decode()
            #     encoded_message = self.client_socket.recv(int(msg_length))
            # except OSError:
            #     return
            
            # try:
            #     message = json.loads(encoded_message.decode())
            # except Exception as e:
            #     print(f"message {encoded_message.decode()} caused exception {e}")
            #     exit()
            message = SenderReceiver.receive_message(self.client_socket)
            
            if message is None: return
                
            # print(message)
            if message["file_exists"] == True:
                filename = message["args"][1]
                file_bytes = message["file"]
                self.save_file(filename, file_bytes)
            
            elif message["message_type"] == "command":
                self.handle_server_command(message)
                
            elif message["message_type"] == "basic":
                print(message["message"])
            
            
    def handle_server_command(self, message):
        command = message["command"]
        if command == "/shutdown":
            self.shutdown()
            return
        elif command == "/switch":
            args = message["args"]
            self.switch(args)
            return
            
            
    def shutdown(self):
        self.close_socket()
        self.shutdown_queue.put(1)
        self.shutdown_client = True
    
    
    def switch(self, args):
        """
        When switching clients channel set the server_port to be the new channel
        and close the current socket

        Args:
            args (_type_): _description_
        """
        # print("in switch")
        new_channel_port = int(args[0])
        self.server_port = new_channel_port
        self.close_socket()

        
    def close_socket(self):
        # self.client_socket.shutdown(socket.SHUT_RDWR)
        # print("Closing socket")
        self.client_socket.close()
    
            
        
        
        
def main():
    client = Client()
    client.start()
    
        
if __name__ == "__main__":
    main()
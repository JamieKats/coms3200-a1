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
    
    NOTES FOR JAMIE
    - when client exits early (crashes) server crashes because it tries to close pipes for 
    the client that has already died
    - in readme specify that channel is refering to the collection of chat lobby and queue
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

AFK_TIME_LIMIT = 100


class Server:
    def __init__(self) -> None:
        """
        One thread listens for incomming connections
        One thread created for every client connection
        One thread to handle stdin input
        """
        if len(sys.argv) != 2:
            exit(1)
        
        config_path = sys.argv[CONFIG_COMMAND]
        
        self.channel_configs = {}
        self.load_config(config_path)
        
        # initialise channels
        self.channels: dict = self.create_channels()
        
        self.threads = []
    
        # set signal handler
        signal.signal(signal.SIGINT, self.shutdown)
        
        # queue for messages from server command/client messages to buisness logic thread
        self.client_message_queue = queue.Queue()
        
        self.server_command_queue = queue.Queue()
        
        self.shutdown_server = False
        
        # threads send message to this queue if the system should shutdown
        self.shutdown_queue = queue.Queue()
        
        
    # NOTE two shutdowns temporary, one for sigint one for shutdown command
    def shutdown(self, signum=None, frame=None):
        """
        TODO need to close all channel sockets on shutdown

        Args:
            signum (_type_, optional): _description_. Defaults to None.
            frame (_type_, optional): _description_. Defaults to None.
        """
        # close all client sockets in queues and channels
        for channel in self.channels.values():
            channel.shutdown()
        
        # close bind socket
        
        # print("above server_socket shutdown in server.shutdown()")
        # self.server_socket.shutdown(socket.SHUT_RDWR)
        # self.server_socket.close()
        
        # close command daemon thread
        
        
        # exit process
        time.sleep(1) # NOTE tmp sleep aded before exit to allow daemon threads to throw exceptions to fix
        exit()
        
    def get_clients_channel(self, username: str):
        """
        Returns the channel the client is apart of. None otherwise

        Args:
            username (str): _description_
        """
        for channel in self.channels.values():
            if channel.get_client_in_channel(username) is not None:
                return channel
            
    def get_channel(self, channel_name: str):
        """
        Returns the channel if it exists, None otherwise

        Args:
            channel_name (str): _description_
        """
        for channel in self.channels.values():
            if channel.name == channel_name:
                return channel
        return None
        
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
            capacity = config_options[3]
            
            self.channel_configs[name] = {
                # "name": name,
                "port": port,
                "capacity": capacity
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
        for channel_name, channel_info in self.channel_configs.items():
            port = int(channel_info["port"])
            capacity = int(channel_info["capacity"])
            
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
            args=(self.server_command_queue, ),
            daemon=True)
        server_command_thread.start()
        
        # create thread to process channel queues, and execute logic when a 
        # client msg or server command is received
        server_logic_thread = threading.Thread(
            target=self.server_logic_thread,
            args=(self.client_message_queue, self.server_command_queue, self.channels, ),
            daemon=True)
        self.threads.append(server_logic_thread)
        server_logic_thread.start()
        
        # start up server threads to listen to channel sockets for incoming 
        # connections
        self.start_channel_listeners()
        
        # when a msg sent to shutdown queue, start server shutdown process
        self.shutdown_queue.get(block=True)
        self.shutdown()
         
            
    def server_command_thread(self, server_command_queue: queue.Queue):
        while True:
            server_command = input().strip().split(" ")
            command = server_command[0]
            args = server_command[1:]
            message = {
                "messsage_type": "server_command",
                "command": command,
                "args": args
            }
            server_command_queue.put(message)
            
            # if message["message"] == "/shutdown":
            #     self.shutdown_queue.put(1)
            #     return
            # elif 
    

    def client_listener_thread(self, client: ServerClient, channel: Channel):
        # if client already exists with same name in channel close client
        if channel.client_in_channel(client.name):
            message = {
                'message_type': 'basic',
                'message': f"[Server message ({get_time()})] Cannot connect to the {channel.name} channel."
            }
            client.send_message(message)
            client.shutdown()
            return
            
        # add client to channel queue
        channel.add_client_to_queue(client)
        
        while True:
            try:
                # message = client.connection_socket.recv(MSG_BUFFER_SIZE)
                message = client.receive_message()
                # print(message)
            except ConnectionResetError as e:
                print(f"Returning early from client_listener_thread: {e}")
                return
            
            # return if empty message received indicating closed socket
            # if message == b'' or message is None:
            #     return
            
            # message = json.loads(message.decode())
            
            if message is None: return
            
            # check if message first word is valid command
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
            # TODO need to attach port user is from to the message somehow
            # message["port"] = channel.port
            
            self.client_message_queue.put(message)
            
    
    def server_logic_thread(self, client_message_queue, server_command_queue, channels):
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

            self.process_client_messages(client_message_queue)

            self.process_server_commands(server_command_queue)
            
            self.check_afk_users(channels)
       
            time.sleep(0.01)


    def start_channel_listeners(self):
        for channel in self.channels.values():
            channel_listener_thread = threading.Thread(
                target=self.channel_listen_thread,
                args=(channel, ),
                daemon=True
            )
            channel_listener_thread.start()


    def channel_listen_thread(self, channel: Channel):
        while True:
            # If OSError thrown because of closed socket return
            try:
                connection_socket, addr = channel.conn_socket.accept()
            except OSError:
                return
            
            # receive first message from client with clients username
            client_settings = connection_socket.recv(MSG_BUFFER_SIZE).decode()
            client_settings = json.loads(client_settings)
            client = ServerClient(
                name=client_settings["username"],
                conn_socket=connection_socket,
                addr=addr)
            
            # create listener thread for new user
            client_listener_thread = threading.Thread(
                target=self.client_listener_thread,
                args=(client, channel),
                daemon=True)
            self.threads.append(client_listener_thread)
            client_listener_thread.start()
            
            
    def process_channel_queues(self, channels):
        for channel in channels.values():
            # print(f"Size of queue = {len(channel.waiting_queue)}")
            # print(f"Num of people in lobby = {len(channel.chat_lobby)}/{channel.max_users}")
            users_in_lobby = len(channel.chat_room)
            if users_in_lobby < channel.capacity:
                # print("IN PROCESS CHANNEL QUEUES")
                users_to_add = min(
                    channel.capacity - users_in_lobby, 
                    len(channel.client_queue))
                
                for i in range(0, users_to_add):
                    channel.move_client_to_lobby()
            
        
    def process_client_messages(self, incoming_queue: ClientQueue):
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
        # print(message)
        
        client_name = message["sender"]
        channel: Channel = message["channel"]
        client: ServerClient  = channel.get_client_in_channel(client_name)
        
        # reset AFK timer when client sends msg/cmd when not muted
        if client.is_muted() == False:
            client.time_last_active = time.time()
            
        if message["message_type"] == "client_command":
            self.handle_client_command(message)
            return
        
        
        
        # if normal msg
        # TODO befor this 'if' need to check if client is muted or not
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
            print(formatted_msg)
            server_msg = {
                'message_type': 'basic',
                'message': formatted_msg
            }
            
            for user in channel.chat_room:
                if user.name != client_name:
                    user.send_message(server_msg)
    
    
    def process_server_commands(self, server_command_queue):
        try:
            message = server_command_queue.get(block=False)
        except queue.Empty as e:
            return
        if message["command"] not in VALID_SERVER_COMMANDS:
            return
        
        self.handle_server_command(message)
        
    def check_afk_users(self, channels):
        message = {
            "message_type": "basic",
        }
        for channel in channels.values():
            for client in channel.chat_room:
                if client.is_muted(): continue
                
                if client.time_last_active + AFK_TIME_LIMIT < time.time():
                    channel.remove_client_from_channel(client.name)
                    client.shutdown()
                    
                    message["message"] = f"[Server message ({get_time()})] {client.name} went AFK."
                    channel.send_message(message)
                    print(message["message"])
                    
                
            for client in channel.client_queue:
                if client.is_muted(): continue
                
                if client.time_last_active + AFK_TIME_LIMIT < time.time():
                    channel.remove_client_from_channel(client.name)
                    client.shutdown()
                    
                    message["message"] = f"[Server message ({get_time()})] {client.name} went AFK."
                    channel.send_message(message)
                    print(message["message"])
                
    
    def get_user(self, username: str) -> ServerClient:
        """
        Returns the user object for the username given, if the user doesnt 
        exist in any channels None is returned.

        Args:
            username (str): _description_

        Returns:
            User: _description_
        """
        for channel in self.channels.values():
            for client in channel.chat_room:
                if client.name == username:
                    return client
            for client in channel.client_queue:
                if client.name == username:
                    return client
        return None
    
    def handle_client_command(self, message):
        # print()
        # print(message)
        # print()
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
                
                
    def whisper(self, received_message):
        # if client muted dont process message
        client = self.get_user(received_message["sender"])
        if client.is_muted():
            message = {
                "message_type": "basic",
                "message": f"[Server message ({get_time()})] You are still muted for {client.remaining_time_muted()} seconds."
            }
            client.send_message(message)
            return
            
        args = received_message['args']
        whisper_target = args[0]
        whisper_message = args[1]
        
        target_channel: Channel = received_message["channel"]
        if target_channel.get_client_in_chat_room(whisper_target) is None:
            # whisper target not in chat lobby
            no_user_msg = f"[Server message ({get_time()})] {whisper_target} is not here." 
            message = {
                "message_type": "basic",
                "message": no_user_msg,
                "receiver": received_message["sender"]
            }
        else:
            formated_whisper = f"[{received_message['sender']} whispers to you: {get_time()}] {whisper_message}"
            message = {
                "message_type": "basic",
                "message": formated_whisper,
                "receiver": whisper_target
            }
        target_channel.send_message(message, message["receiver"])
        
        # print server whisper message
        server_msg = f"[{received_message['sender']} whispers to {whisper_target}: ({get_time()})] {whisper_message}"
        print(server_msg)

    
    def quit(self, message):
        sender: str = message["sender"]
        # channel_name: str = message["channel"].name
        
        # channel: Channel = self.channels[channel_name]
        channel: Channel = message["channel"]
        channel.close_client(sender)
        
        
    def list(self, message):
        username = message["sender"]
        client: ServerClient = self.get_user(username)
        
        for channel in self.channels.values():
            channel_msg = f"[Channel] {channel.name} {len(channel.chat_room)}/{channel.capacity}/{len(channel.client_queue)}."
            message = {
                "message_type": "basic",
                "message": channel_msg
            }
            client.send_message(message)
            
        
    def switch(self, message):
        args = message["args"]
        new_channel_name = args[0]
        new_channel: Channel = self.get_channel(new_channel_name)
        sender_username = message["sender"]
        sender: ServerClient = self.get_user(sender_username)
        
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
        
        # remove sender from existing channel and put in new channel queue
        current_channel: Channel = message["channel"]
        # current_channel_port: int = current_channel.port
        current_channel.remove_client_from_channel(sender_username)
        
        message = {
            "message_type": "basic",
            "message": f"[Server message ({get_time()})] {sender_username} has left the channel."
        }
        
        self.send_message(message)
        print(message["message"])
        
        # send client msg to close socket and reconnect on new port then close client connection
        sender.switch_channel([new_channel.port])
        
    
    def send(self, message):
        # target client not in channel
        target_client = message["args"][0]
        file_path = message["args"][1]
        
        channel: Channel = self.get_clients_channel(message["sender"])
        
        reply_message = {
            "message_type": "basic",
        }
        
        # the target client is not in the senders channel
        if channel.client_in_channel(target_client) == False:
            reply_message["message"] = f"[Server message ({get_time()})] {target_client} is not here."
            channel.send_message(reply_message, message["sender"])
            return
        
        # the file path does not exist
        if message["file"] == b'':
            reply_message["message"] = f"[Server message ({get_time()})] {file_path} does not exist."
            channel.send_message(reply_message, message["sender"])
            return
        
        reply_message["message"] = f"[Server message ({get_time()})] You sent {file_path} to {target_client}."
        channel.send_message(reply_message, message["sender"])
        
        print(f"[Server message ({get_time()})] {message['sender']} sent {file_path} to {target_client}.")
        
        # send msg with file
        # NOTE remove "channel" key so json dumps doesnt fail
        del message["channel"]
        channel.send_message(message, target_client)
        
            
        
        
        
        # return
        # print(f"msg receeived in send:\n{message}")
        # print(message["file"]
        
    
    def handle_server_command(self, message):
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
            
    def kick(self, args):
        channel_name = args[0].split(":")[0]
        username = args[0].split(":")[1]
        
        channel: Channel = self.get_channel(channel_name)
        
        # channel doesnt exist
        if channel is None:
            print(f"[Server message ({get_time()})] {channel_name} does not exist.")
            return
        
        # client not in specified channel
        if channel.client_in_channel(username) == False:
            print(f"[Server message ({get_time()})] {username} is not in {channel_name}.")
            return
        
        client: ServerClient = channel.get_client_in_channel(username)
        channel.remove_client_from_channel(username)
        client.shutdown()
        
        message = {
            "message_type": "basic",
            "message": f"[Server message ({get_time()})] {username} has left the channel."
        }
        channel.send_message(message)
        
        print(f"[Server message ({get_time()})] Kicked {username}.")
        

    def mute(self, args):
        channel_name = args[0].split(":")[0]
        username = args[0].split(":")[1]
        time_muted = args[1]
        
        # time must be positive integer
        try:
            time_muted = int(time_muted)
            if time_muted < 1: raise Exception
        except Exception as e:
            print(f"[Server message ({get_time()})] Invalid mute time.")
            return
        
        # user or channel doesnt exist
        if self.get_channel(channel_name) is None or self.get_user(username) is None:
            print(f"[Server message ({get_time()})] {username} is not here.")
            return
            
        # user exists and time is valid
        client = self.get_user(username)
        
        client.mute(time_muted)
        print(f"[Server message ({get_time()})] Muted {username} for {time} seconds.")
        
        message = {
            "message_type": "basic"
        }
        
        channel: Channel = self.get_channel(channel_name)
        for client in channel.chat_room:
            if client.name == username:
                message["message"] = f"[Server message ({get_time()})] You have been muted for {time_muted} seconds."
            else:
                message["message"] = f"[Server message ({get_time()})] {username} has been muted for {time_muted} seconds."
            client.send_message(message)

            
            
        
    
    def empty(self, args):
        channel_name = args[0]
        channel: Channel = self.get_channel(channel_name)
        
        if channel is None:
            print(f"[Server message ({get_time()})] {channel_name} does not exist.")
            return

        for client in channel.chat_room.copy():
            channel.remove_client_from_channel(client.name)
            client.shutdown()
            
        print(f"[Server message ({get_time()})] {channel_name} has been emptied.")
    
        
    
        
        
def main():
    server = Server()
    server.start()
        
if __name__ == '__main__':
    main()
        
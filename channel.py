import socket
import threading
from server_client import ServerClient
from client_queue import ClientQueue
from utils import get_time

class Channel:
    """
    A channel in the chat application contains a waiting queue and a chat room.
    New users are put in the waiting queue and and moved into the chat room 
    when there is space for them
    """
    def __init__(self, name, port, capacity, conn_socket) -> None:
        self.name: str = name
        self.port: int = port
        self.capacity: int = capacity
        self.chat_room: list = []
        self.client_queue: ClientQueue = ClientQueue()
        self.conn_socket: socket.socket = conn_socket
        self.lock = threading.Lock()
        
        
    def add_client_to_queue(self, client: ServerClient) -> None:
        """
        Adds a client to the channel waiting queue.
        
        If the client is at the start of the queue and there is space in the 
        chat lobby then the client is put straight into the chat room. 
        Otherwise the client receives a message letting them know their 
        position in the queue.

        Args:
            client (ServerClient): the client to add to the queue
        """
        self.lock.acquire()
        
        spaces_in_chat_room = self.capacity - len(self.chat_room)
        self.client_queue.put(client, self.name, spaces_in_chat_room)
        
        self.lock.release()
        # # send client welcome message            
        # welcome_msg = f"[Server message ({get_time()})] Welcome to the " \
        #     + f"{self.name} channel, {client.name}."
        # message = {
        #     'message_type': 'basic',
        #     'message': welcome_msg
        # }
        # client.send_message(message)
        
        # # return early if client added is only one in queue and there is a free 
        # # spot in the lobby
        # if len(self.client_queue) == 1 and len(self.chat_room) < self.capacity:
        #     return
        
        # # send the client the queue location message
        # queue_loc_msg = f"[Server message ({get_time()})] You are in the " \
        #     + f"waiting queue and there are {len(self.client_queue) - 1} " \
        #     + "user(s) ahead of you."
        # message = {
        #     'message_type': 'basic',
        #     'message': queue_loc_msg
        # }
        # client.send_message(message)


    def move_client_to_lobby(self) -> None:
        """
        Moves the client from the waiting queue to the chat room.
        """
        self.lock.acquire()
        
        # if noone in wating queue return early
        if len(self.client_queue) == 0:
            return
        
        # get next user and add to chat lobby
        user = self.client_queue.get()
        self.chat_room.append(user)
        
        # send <username> joined message to everyone in channel
        join_message = f"[Server message ({get_time()})] {user.name} has "\
            + "joined the channel."
        message = {
            "message_type": 'basic',
            'message': join_message
        }
        self.send_message_clients_in_channel(message)
        
        # print user joined message to servers stdout
        server_msg = f"[Server message ({get_time()})] {user.name} has joined"\
            + f" the {self.name} channel."
        print(server_msg, flush=True)
        
        self.lock.release()
        
    
    def remove_client_from_channel(self, username: str) -> None:
        """
        Removes the given client from the channel chat_room or queue. Asssumes
        the client exists in the channel

        Args:
            username (str): the username of the client to remove
        """
        # get client if in chat room or queue
        client_in_chat_room: ServerClient = self.get_client_in_chat_room(username)
        client_in_queue: ServerClient = self.get_client_in_queue(username)

        if client_in_chat_room is not None:
            self.chat_room.remove(client_in_chat_room)
            return
            
        if client_in_queue is not None:
            self.client_queue.remove_client(client_in_queue)
            return
        
        
    def send_message_clients_in_channel(self, message: dict, username:str = None) -> None:
        """
        Sends the message to all users in the channel if user=None,
        otherwise the message is sent only to the user specified.

        Args:
            message (dict): the message to send to the client
            username (str, optional): username of the client to send an 
            individial message to. Defaults to None.
        """
        # is username specified send message to only that user
        if username is not None:
            for chat_client in self.chat_room:
                if username == chat_client.name:
                    chat_client.send_message(message)
            return
        
        # send message to everyone in room
        for chat_client in self.chat_room:
            chat_client.send_message(message)
            
            
    def shutdown(self) -> None:
        """
        Send shutdown message to all clients in queue and chat lobby, and 
        close sockets
        """
        # close client connections
        client: ServerClient
        for client in self.client_queue:
            client.shutdown(graceful_shutdown=True)
        
        for client in self.chat_room:
            client.shutdown(graceful_shutdown=True)
            
        # close the channel socket
        self.conn_socket.shutdown(socket.SHUT_RDWR)
        self.conn_socket.close()
            
            
    def get_client_in_chat_room(self, username: str) -> ServerClient:
        """
        Returns the client in the chat room with the username provided.

        Args:
            username (str): name of the client to get

        Returns:
            ServerClient: client with the username given. None if the client 
            isn't in the channel.
        """
        for chat_user in self.chat_room:
            if chat_user.name == username:
                return chat_user
        return None
    
    
    def get_client_in_queue(self, username: str) -> ServerClient:
        """
        Gets the client with the username given in the queue.
        Checks if the given username exists in the queue, returns User if so, 
        None otherwise

        Args:
            username (str): name of the client to get

        Returns:
            ServerClient: client with the username given. None if the client 
            isn't in the channel.
        """
        for chat_user in self.client_queue:
            if chat_user.name == username:
                return chat_user
        return None
        
    def get_client_in_channel(self, username: str) -> ServerClient:
        """
        Gets the user from the channel waiting queue or chat room.

        Args:
            username (str): name of the client to get

        Returns:
            ServerClient: client with the username given. None if the client 
            isn't in the channel.
        """
        client_in_chat_room = self.get_client_in_chat_room(username)
        if client_in_chat_room is not None:
            return client_in_chat_room
        
        client_in_queue = self.get_client_in_queue(username)
        if client_in_queue is not None:
            return client_in_queue
        
        return None
    
    
    def client_in_channel(self, username: str) -> bool:
        """
        Checks if the client with the username given is in the channel chatroom 
        or queue.

        Args:
            username (str): name of the client to get

        Returns:
            bool: True if the client is in the channel. False otherwise.
        """
        client_in_chat_room = self.get_client_in_chat_room(username)
        if client_in_chat_room is not None:
            return True
        
        client_in_queue = self.get_client_in_queue(username)
        if client_in_queue is not None:
            return True
        
        return False
    
    
    def where_is_client(self, username: str) -> str:
        """
        Returns the name of the location of the client. If the client is in the 
        chat room "chatroom" is returned, if client in queue "queue" returned,
        otherwise None returned

        Args:
            username (str): _description_

        Returns:
            bool: _description_
        """
        client_in_chat_room = self.get_client_in_chat_room(username)
        if client_in_chat_room is not None:
            return "chatroom"
        
        client_in_queue = self.get_client_in_queue(username)
        if client_in_queue is not None:
            return "queue"
        
        return None
    
    
    def close_client(self, username: str, graceful_shutdown: bool, client_kicked:bool=False) -> None:
        """
        Sends the client a shutdown command before closing threads and 
        connections for client.

        Args:
            username (str): name of the client to get
        """
        client: ServerClient = self.get_client_in_channel(username)
        if client is None:
            return
        
        # check if client in queue or chat room, if they are in queue, remove 
        # them and dont send leaving message
        client_loc = self.where_is_client(username)
        # print(f"client is in {client_loc}")
         
        self.remove_client_from_channel(username)
        
        # publish client leaving message to channel
        message = {
            "message_type": "basic",
            "message": f"[Server message ({get_time()})] {username} has left the channel."
        }
        
        server_kick_message = f"[Server message ({get_time()})] Kicked {username}."

        # send client leaving message to everyone in channel and print for server
        # only when client shutsdown_gracefully
        if graceful_shutdown == True and client_loc == "chatroom":
            self.send_message_clients_in_channel(message)
            if client_kicked == False:
                print(message["message"], flush=True)
            elif client_kicked == True:
                print(server_kick_message, flush=True)
                
        elif graceful_shutdown == True and client_loc == "queue":
            if client_kicked == True:
                print(message["message"], flush=True)
            elif client_kicked == False:
                print(server_kick_message, flush=True)
        
        # shutdown client
        client.shutdown(graceful_shutdown=graceful_shutdown)
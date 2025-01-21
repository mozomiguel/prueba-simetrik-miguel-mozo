# Cliente GRPC
import grpc
import message_service_pb2
import message_service_pb2_grpc
import os

def run():
    alb_host = os.getenv('ALB_ADDRESS','')
    print(alb_host)
    with grpc.insecure_channel(alb_host+':80') as channel:
        stub = message_service_pb2_grpc.MessageServiceStub(channel)
        message = "Hello, Server!"
        response = stub.SendMessage(message_service_pb2.MessageRequest(message=message))
        print(f"Server reply: {response.reply}")

if __name__ == "__main__":
    run()
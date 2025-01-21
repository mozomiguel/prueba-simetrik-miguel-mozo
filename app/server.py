# Server GRPC
import grpc
from concurrent import futures
import message_service_pb2
import message_service_pb2_grpc

class MessageServiceServicer(message_service_pb2_grpc.MessageServiceServicer):
    def SendMessage(self, request, context):
        print(f"Received message from client: {request.message}")
        return message_service_pb2.MessageResponse(reply=f"Message received: {request.message}")

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    message_service_pb2_grpc.add_MessageServiceServicer_to_server(MessageServiceServicer(), server)
    server.add_insecure_port('[::]:50051')
    print("Server is running on port 50051")
    server.start()
    server.wait_for_termination()

if __name__ == "__main__":
    serve()
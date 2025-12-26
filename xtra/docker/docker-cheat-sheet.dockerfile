# docker build info
# parts to a Dockerfile for building local "image"
Command    # Description
ADD        # Copies a file from the host system onto the container
CMD        # The command that runs when the container starts
ENTRYPOINT # sets the concrete default application that is used every time a container is created using the image
ENV        # Sets an environment variable in the new container
EXPOSE     # Opens a port for linked containers
FROM       # The base image to use in the build. This is mandatory and must be the first command in the file.
LABEL      <key>=<value> <key>=<value> metadata
ONBUILD    # A command that is triggered when the image in the Dcokerfile is used as a base for another image
RUN        # Executes a command and save the result as a new layer
USER       # Sets the default user within the container
VOLUME     # Creates a shared volume that can be shared among containers or by the host machine
WORKDIR    # Set the default working directory for the container
# Once you've created a Dockerfile and added all your instructions, you can use it to build an image using

# docker build -f /path/to/Dockerfile # example
FROM ubuntu:16.04
LABEL "com.example.vendor"="ACME Incorporated"
LABEL com.example.label-with-value="foo"
LABEL version="1.0"
LABEL description="This text illustrates \
that label-values can span multiple lines."
RUN apt-get update
RUN apt-get install -y git
RUN git clone <repo-path>
RUN echo 'My docker image' > /usr/share/myimage/html/index.html
EXPOSE 80

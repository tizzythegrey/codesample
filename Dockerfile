FROM python:2.7
RUN mkdir /code
WORKDIR /code
ADD requirements.txt /code/
ADD mycodesample /code/
EXPOSE 8000
RUN pip install -r requirements.txt
ENTRYPOINT exec python /code/manage.py runserver 0.0.0.0:8000

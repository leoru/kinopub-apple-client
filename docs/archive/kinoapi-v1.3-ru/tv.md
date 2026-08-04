ТВ-трансляции — API 1.3 3 documentation

#
  
Содержание  
-

ТВ-трансляции  
  -

Введение
  -

Список транслируемых каналов
  
##

Транслируемые, на данный момент, каналы. Обычно это какие-то события типа Евро 2016, Рио 2016.

##

Запрос:

```
GET https://api.service-kp.com/v1/tv

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
    'channels': [
        {
            'id': 1,
            'title': 'Матч! ТВ',
            'name': 'matchtv',
            'logos': [
                's': 'http://url/to/small-image',
            ],
            'stream': 'http://url/to/stream/playlist.m3u8',
        }
    ]
]

```

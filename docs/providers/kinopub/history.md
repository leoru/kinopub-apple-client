История — API 1.3 3 documentation

#
  
Содержание  
-

История  
  -

Введение
  -

Получение истории просмотров
  -

Очистить просмотр для media
  -

Очистить просмотр для media
  -

Очистить просмотр для item
  
##

Управление историей просмотров

##
  
**Параметры запроса:**

-

*[page]* - номер страницы
-

*[perpage]* - кол-во на страницы, по умолчанию 20, максимум 50.

Запрос:

```
GET https://api.service-kp.com/v1/history

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

{
    "history": [
        {
            "time": 123, // время где остановились
            "counter": 1, //сколько раз смотрели данный media
            "first_seen": 12344545, // unixtime, когда впервые посмотрели media
            "last_seen": 1234556, // unixtime, когда последний раз посмотрели media
            "item": {}, // описание item
            "media": {},  // описание media
        }
    ],
    "pagination": {
        "total": 123,
        "current": 1,
        "perpage: 123,
        "total_items": 123,
    },
}

```

##
  
**Параметры запроса:**

-

*id* - идентификатор media

Запрос:

```
POST https://api.service-kp.com/v1/history/clear-for-media?id=123

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

```

##
  
**Параметры запроса:**

-

*id* - идентификатор season

Запрос:

```
POST https://api.service-kp.com/v1/history/clear-for-season?id=123

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

```

##
  
**Параметры запроса:**

-

*id* - идентификатор item

Запрос:

```
POST https://api.service-kp.com/v1/history/clear-for-item?id=123

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

```

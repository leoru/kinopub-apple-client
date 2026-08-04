Устройства — API 1.3 3 documentation

#
  
Содержание  
-

Устройства  
  -

Введение
  -

Список устройств на аккаунте
  -

Удаление текущего устройства
  -

Удаление устройства
  -

Информация о устройстве
  -

Информация о текущем устройстве
  -

Настройки устройства
  -

Изменение информации о текущем устройстве
  
##

Просмотр и управление устройствами. После активации устройства и при каждом запуске плагина желательно отсылать информацию по устройству через /device/notify

##

Запрос:

```
GET https://api.service-kp.com/v1/device

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
    'devices': [
        {
            'id': 1,
            'title': 'AppleTV Hall',
            'hardware': 'AppleTV/5.3',
            'software': 'iOS/8.3'
            'created': 12345667,
            'updated': 12345678
            'last_seen': 12345678,
            'is_browser': 0,
            'settings: {
              // Список настроек
            }
        }
    ]
]

```

##

Запрос:

```
POST https://api.service-kp.com/v1/device/unlink

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
]

```

##
  
**Параметры запроса:**

-

**id** - id устройства.

Запрос:

```
POST https://api.service-kp.com/v1/device/remove?id=123
POST https:/api.service-kp.com/v1/device/123/remove

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[

    'status': 200,
     // bool. Указывает, что данный запрос вызван текущим устройством или нет.
     // Удаление текущего устройства/браузера равносильно логауту.
    'current: true,
]

```

##

Запрос:

```
GET https://api.service-kp.com/v1/device/123

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
    'device': {
        'id': 1,
        'title': 'AppleTV Hall',
        'hardware': 'AppleTV/5.3',
        'software': 'iOS/8.3'
        'created': 12345667,
        'updated': 12345678,
        'last_seen': 12345678,
        'settings: {
          // Список настроек
        }
    }
]

```

##

Запрос:

```
GET https://api.service-kp.com/v1/device/info

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
    'device': {
        'id': 1,
        'title': 'AppleTV Hall',
        'hardware': 'AppleTV/5.3',
        'software': 'iOS/8.3'
        'created': 12345667,
        'updated': 12345678,
        'last_seen': 12345678,
        'is_browser': 0,
        'settings: {
          // Список настроек
        }
    }
]

```

##

На данный момент все настройки разбиваются на тип “чекбокс” и “список”. “Чекбокс” это настройки вида да/нет (1/0). Если не указан type, значит настройка трактуется как “чекбокс”. Если указан type: ‘list’, значит надо обрабатывать как список, формат:

```
'serverLocation': {
   'type': 'list',
   'value': [
      {
         'id': 1,
         'label': 'Германия',
         'description': '',
         'selected': 1,
      }
   ],
},

```
  
Набор полей в списках всегда одинаков - id,label,description,selected.  

**Доступные настройки:**

-

**supportSsl** boolean - Поддерживает ли устройство SSL
-

**supportHevc** boolean - Поддерживает ли устройство HEVC
-

**supportHdr** boolean - Поддерживает ли устройство HDR (10bit color)
-

**support4k** boolean - Поддерживает ли устройство UHD/4K
-

**mixedPlaylist** boolean - На данный момент только для HLS4, плейлист строится из всех доступных файлов AVC+HEVC.
-

**streamingType** integer - Идентификатор типа стриминга, список типов Список типов стриминга
-

**serverLocation** integer - Идентификатор региона, откуда получать контент, список типов Список локаций сервера

Получение настроек:

```
GET https://api.service-kp.com/v1/device/123/settings

 HTTP/1.1 200 OK
 Content-Type: application/json

 [
     'status': 200, // 400 если ошибка
     'settings': {
         'useSsl': {
            'label': 'Использовать SSL',
            'value': 1,
         },
         'supportHevc': {
            'label': 'Использовать SSL',
            'value': 1,
         },
         'settingKey': {
            'label': 'Setting label in UI',
            'value': 'setting value',
         },
         'serverLocation': {
            'type': 'list',
            'value': [
               {
                  'id': 1,
                  'label': 'Германия',
                  'description': '',
                  'selected': 1,
               }
            ],
         },
         'streamingType: {
            'type': 'list',
            'value': [
               {
                  'id': 1,
                  'label': 'HLS',
                  'description': '',
                  'selected': 1,
               }
            ],
         }
     },
 ]

```
  
Изменение настроек::

```
POST https://api.service-kp.com/v1/device/123/settings
{'useSsl': true, 'support4k': false }

 HTTP/1.1 200 OK
 Content-Type: application/json

 [
   'status': 200,
 ]

```

##
  
**Параметры запроса:**

-

**title** - Название устройства.
-

**hardware** - Информация по “железу” устройства.
-

**software** - Информация по софту устройства.

Запрос:

```
POST https://api.service-kp.com/v1/device/notify

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200, // 400 если ошибка
]

```

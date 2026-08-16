Закладки — API 1.3 3 documentation

#
  
Содержание  
-

Закладки  
  -

Введение
  -

Список папок в закладках
  -

Список фильмов/сериалов в папке
  -

Список папок в которых присутствует фильм
  -

Создать папку
  -

Добавление фильма в папку
  -

Удаление папки
  -

Удаление фильма из папки/папок
  -

Переключение добвить/удалить фильм
  
##

Просмотр и управление закладками пользователя

##

Запрос:

```
GET https://api.service-kp.com/v1/bookmarks

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
    'items': [
        {
            'id': 1,
            'title': 'Семейные',
            'views': 10,
            'count': 23,
            'created': 12345667,
            'updated': 12345678
        }
    ]
]

```

##

Два варианта запросов, для обратной совместимости.

Запрос:

```
GET https://api.service-kp.com/v1/bookmarks/view?folder=<id>
GET https://api.service-kp.com/v1/bookmarks/<id>

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
    'folder': {
        'id': 1,
        'title': 'Семейные',
        'views': 10,
        'created': 12345667,
        'updated': 12345678
    }
    'items': []
]

```
  
Пример содержания *items* смотрите в: Список медиа

##

Запрос:

```
GET https://api.service-kp.com/v1/bookmarks/get-item-folders?item=<id>

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
    'folders': [
        {
            'id': 1,
            'title': 'Семейные',
            'views': 10,
            'created': 12345667,
            'updated': 12345678
        }
    ]
]

```

##

Запрос:

```
POST https://api.service-kp.com/v1/bookmarks/create

```

**Параметры запроса:**

-

**title** - название папки.

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
    'folder': {
        'id': 134,
        'title': 'Название',
        'views': 10,
        'created': 12312334,
        'updated': 1231233123,
    }
]

```

##

Запрос:

```
POST https://api.service-kp.com/v1/bookmarks/add

```

**Параметры запроса:**

-

**item** - идентификатор фильма
-

**folder** - идентификатор папки

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
]

```

##

Запрос:

```
POST https://api.service-kp.com/v1/bookmarks/remove-folder

```

**Параметры запроса:**

-

**folder** - идентификатор папки

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
]

```

##

Запрос:

```
POST https://api.service-kp.com/v1/bookmarks/remove-item

```

**Параметры запроса:**

-

**item** - идентификатор фильма
-

**[folder]** - идентификатор папки, если отсутствует - удаляем из всех папок.

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
]

```

##

Если фильм отсутствует в заданной папке, он добавится в нее, иначе удалится.

Запрос:

```
POST https://api.service-kp.com/v1/bookmarks/toggle-item

```

**Параметры запроса:**

-

**item** - идентификатор фильма
-

**folder** - идентификатор папки

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
]

```

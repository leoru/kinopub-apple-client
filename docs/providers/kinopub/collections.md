Подборки — API 1.3 3 documentation

> 🔎 **Обратного метода здесь нет, а PWA его использует.** Снято 2026-08-16, нами не проверено.
> «В каких подборках лежит этот айтем»:
>
> ```
> GET https://api.ios-kp.store/api2/v1.1/items/collections/{item_id}
> ```
> ```json
> { "items": [ { "id": 178, "title": "22 фильма о криминальной России",
>                "posters": { "small": "…", "medium": "…", "big": "…" },
>                "created": 1459926998, "updated": 1460448804,
>                "views": 7022, "watchers": 84 } ], "status": 200 }
> ```
>
> - У подборки **нет `wide`** среди постеров, и путь `/selection/`, а не `/poster/item/`.
> - Два счётчика, которых больше нигде нет: `views` и `watchers`.
> - Готовая секция «этот фильм входит в подборки» для детальной страницы.
> - Метод из ветки `api2/v1.1` — **на нашем базовом хосте его нет**. Проверено вживую 2026-08-17:
>   `GET https://api.service-kp.com/v1/items/collections/248` → **404**, тогда как
>   `https://api.ios-kp.store/api2/v1.1/items/collections/24` отдаёт подборки. Поэтому
>   `ItemCollectionsRequest` — единственный эндпоинт с `baseURLOverride`; всё остальное ходит на
>   зеркало, под которым авторизован пользователь. Принимает ли эта ветка наш токен — ещё не
>   подтверждено.

#
  
Содержание  
-

Подборки  
  -

Список подборок
  -

Список фильмов в подбороке
  
##
  
**Параметры запроса:**

-

**[title]** - Поиск по заголовку, минимум 3 символа. Выборка по типу LIKE ‘$ASD’
-  

****[sort]** - Сортировка, по умолчанию ‘updated-‘. Без знака ‘-‘ сортируется по возрастанию(ASC),**

-

id
  -

title
  -

views
  -

watchers
  -

created
  -

updated

-

**[perpage]** - Пагинация, кол-во на одной странице
-

**[page]** - Пагинация, текущая страница

Запрос:

```
GET https://api.service-kp.com/v1/collections

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
            'watchers': 19,
            'views' => 123,
            'created': 12345667,
            'updated': 12345678,
            'posters': [
                'small' => 'http://media.service-kp.com/small/1.jpg',
                'medium' => 'http://media.service-kp.com/small/1.jpg',
                'big' => 'http://media.service-kp.com/small/1.jpg',
            ],
        }
    ]
]

```

##
  
**Параметры запроса:**

-

**id** - id подборки

Запрос:

```
GET https://api.service-kp.com/v1/collections/view?id=1

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    'status': 200,
    'collection': {
        'id': 1,
        'title': 'Семейные',
        'watchers': 19,
        'views' => 123,
        'created': 12345667,
        'updated': 12345678,
        'posters': [
            'small' => 'http://media.service-kp.com/small/1.jpg',
            'medium' => 'http://media.service-kp.com/small/1.jpg',
            'big' => 'http://media.service-kp.com/small/1.jpg',
        ],
    },
    'items': [ ]
]

```
  
Описание полей ‘items’ смотрите тут

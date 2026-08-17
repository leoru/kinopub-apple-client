Видео контент — API 1.3 3 documentation

#
  
Содержание  
-

Видео контент  
  -

Типы видео контента
  -

Жанры
  -

Страны
  -

Видео контент
  -

Поиск
  -

Похожие видео
  -

Список медиа-контента
  -

Ссылки на субтитры и видео-файлы для media
  -

Ссылка на видео-файл по имени файла
  -

Голосование за видео
  -

Комментарии для фильма/эпизода
  -

Трейлер к контенту
  -

Shortcut - свежие видео
  -

Shortcut - горячие видео
  -

Shortcut - популярные видео
  
##
  
**Видео контент условно разделен на типы:**

-

**movie** - Фильмы
-

**serial** - Сериалы
-

**3D** - 3D Фильмы
-

**concert** - Концерты
-

**documovie** - Документальные фильмы
-

**docuserial** - Документальные сериалы
-

**tvshow** - ТВ Шоу

Запрос:

```
GET https://api.service-kp.com/v1/types

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    {
        'id': 'movie',
        'title': 'Фильмы',
    },
    {
        'id': 'serial',
        'title': 'Сериалы'
    }
]

```

##
  
**Типы жанров:**

-

**movie** - жанры типов видео контента **movie**, **serial**, **3D** (Фильмов и Сериалов)
-

**music** - жанры типов видео контента **concert** (Концерты)
-

**docu** - жанры типов видео контента **documovie**, **docuserial** (Документальные фильмы и сериалы)

Жанры, как и контент, разделены по типам. Видео контент с типом **movie**, **serial**, **3d** может принадлежать только жанрам с типом **movie** и т.д.

Запрос:

```
GET https://api.service-kp.com/v1/genres

```

**Параметры запроса:**

-

**[type]** - фильтр по типу жанров, по умолчанию возвращаются все жанры. Указать можно только один из нижеперечисленных
  -

movie - Обощенный тип
  -

docu  - Обобщенный тип
  -

music  - Обобщенный тип
  -

tvshow  - Обобщенный тип
  -

movie
  -

documovie
  -

serial
  -

docuserial
  -

tvshow
  -

concert
  -

3d
  -

4k

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    {
        'id': 1,
        'title': 'Комедия',
        'type': 'movie'
    },
    {
        'id':10,
        'title': 'Катастрофа',
        'type': 'docu'
    }
    {
        'id': 13,
        'title': Rock,
        'type': music
    }
]

```

##

Запрос:

```
GET https://api.service-kp.com/v1/countries

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/js

[
    {
        'id': 1,
        'title': 'США',
    }
]

```

##

Запрос:

```
GET https://api.service-kp.com/v1/items

```

> 🔎 **`conditions[]` здесь не описан, а PWA им пользуется.** Снято 2026-08-16, нами не
> проверено. Повторяемый параметр со свободным сравнением `<поле><оператор><значение>` —
> это то, чем в веб-клиенте сделаны все галочки фильтра.
>
> **Обрати внимание на метод:** «поиск с фильтрами» в интерфейсе — это **`/v1/items`**, а не
> `/v1/items/search`. Последний ищет текстом по `title` / `director` / `cast`; фильтры и
> `conditions[]` замечены только здесь.
>
> ```
> GET /v1/items
>   ?conditions[]=year<=2020
>   &conditions[]=kinopoisk_rating>=6.0
>   &conditions[]=imdb_rating>=5.0
>   &type=movie&subtitles=rus&genre=2,15&country=2
>   &finished=0&sort=year&quality=4&perpage=20&page=1
> ```
>
> Замечены операторы `<=` и `>=` по `year`, `kinopoisk_rating`, `imdb_rating`. **Насколько
> широк список полей и операторов — неизвестно**, и это первое, что стоит попробовать.
> Остальное из того же запроса: `genre` и `country` принимают список через запятую
> (видели `genre=2,15` и `country=16,2`), `subtitles=rus` фильтрует по наличию субтитров,
> `finished=0` — незавершённые, `quality=4` — свой id качества (не `2160` и не `1080p`),
> `sort=year`.
>
> Наши клиентские фасеты (4K/HD/AC3/минимальный рейтинг) частично дублируют то, что сервер
> умеет сам — перепроверить до того, как расширять клиентские.

**Параметры запроса:**

-

**[type]** - Типы видео контента
-

**[title]** - Поиск по заголовку, минимум 3 символа. Выборка по типу LIKE ‘$ASD’
-

**[genre]** - id жанра. Для множественного поиска список через запятую.
-

**[country]** - id страны. Для множественного поиска список через запятую.
-

**[year]** - Год. Для поиска в промежутке year1-year2
-

**[finished]** - 0/1. Статус сериала, завершен/снимается.
-

**[actor]** - Имена актеров чере запятую или +(плюс), “Actor1,Actor2+Actor3” - ищет (Actor1 OR (Actor2 AND Actor3))
-

**[director]** - Имена режисеров чере запятую или +(плюс), “Actor1,Actor2+Actor3” - ищет (Actor1 OR (Actor2 AND Actor3))
-

> 🔎 **Запятая на `cast` / `director` у нас не сработала.** Проверено вживую 2026-08-17:
> `GET /v1/items?director=Фил%20Лорд,Кристофер%20Миллер&sort=-kinopoisk_rating` отвечает пустым
> списком, тогда как каждое имя по отдельности отдаёт фильмографию. Плюс (AND) не проверяли.
> Поэтому полка «ещё от этих режиссёров» — это **два запроса**, слитых на клиенте
> (`MediaPerson.each(of:role:limit:)`). Документация вендора выше оставлена как есть: это её
> утверждение, а не наше наблюдение.
>
> На `genre` запятую мы, наоборот, используем как OR (`genre=5,23,101`) — **но сами ещё не
> подтвердили**, поэтому в приложении есть откат на один жанр.

**[letter]** - Поиск по первой букве в названиях(рус,анг) фильма
-

**[conditions]** - Массив простых условий для фильтра. Доступные поля как и в сортировке. year <= 100. Объединение условий через AND
-  

****[force]** - Массив для пропуска пользовательских настроек фильтрации**

-

**quality** - Пропускаем проверку на сомнительное качество
  -

**advert**  - Пропускаем проверку на контент с рекламой
  -

**erotic**  - Пропускаем проверку на эротический контент

-

**[sort]** - Сортировка, по умолчанию ‘updated-‘. Без знака ‘-‘ сортируется по возрастанию(ASC), со знаком ‘-‘(минус) по убыванию(DESC). Можно указать можество полей через запятую,.
  -

id
  -

year
  -

title
  -

created
  -

updated
  -

rating
  -

views
  -

watchers

-

**[quality]** - Массив идентификаторов качеств

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/js

{
    'items':[
        {
            'id': 1,
            'title': 'Название / Оригинальное название',
            'type': 'movie', // тип контента
            'subtype': 'multi', // Подтип контента, бывают многосерийные фильмы, концерты
            'year': 2006,
            'cast': 'Актёр 1, Актёр 2',
            'director': 'Режиссёр 1, Режиссёр 2',
            'voice': 'Любительский одноголосый, Оригинал',
            'duration': [
                'average': 123, // Средняя продолжительность для сериалов, полная для фильмов
                'total': 123 //Общая продолжительность фильма, сериала
            ],
            'langs': 2, //Количество аудио дорожек
            'ac3': 0, // Присутствуют или нет AC-3 аудио
            'subtitles': 3, // Количество субтитров
            'quality': 1080, // Качество фильма, для сериалов берется наибольшее количество серий с определенным качеством
            'genres': [
                {
                    'id': 1,
                    'title': 'Комедия'
                },
                {
                    'id': 2,
                    'title': 'Ужасы'
                }
            ],
            'countries': [
                {
                    'id': 1,
                    'title': 'США'
                }
            ],
            'plot': 'Описание фильма',
            'tracklist': [
                {
                    'artist' => 'Исполнитель',
                    'title' => 'Название композиции',
                    'url' => 'ссылка на аудио файл',
                }
            ],
            'imdb': 123,
            'imdb_rating': 123,
            'imdb_votes': 123,
            'kinopoisk': 123,
            'kinopoisk_rating': 123,
            'kinopoisk_votes': 123,
            'rating': 456,
            'views': 15,
            'comments': 5,
            'finished' : false, // Для сериалов: true - окончен, false - снимается
            'advert' : true, // Присутствуют посторонние вставки рекламы
            'in_watchlist': true, // Подписан ли пользователь на сериал
            'subscribed': true, // Подписан ли пользователь на сериал, alias in_watchlist
            'posters': [
                'small': 'http://kino.pub/media/poster/item/small/1.jpg',
                'medium': 'http://kino.pub/media/poster/item/medium/1.jpg';
                'big': 'http://kino.pub/media/poster/item/big/1.jpg';
            ],
            'trailer': {
                'id': 'udNj459jn',
                'url': 'http://www.youtube.com/watch?v=udNj459jn',
            }
        }
    ],
    'pagination': {
        'total': 1,
        'current':1,
        'perpage':1
    }
}

```

##

Поиск производится по полям title, director, cast

Запрос:

```
GET https://api.service-kp.cnom/v1/items/search?q=termi

```

> 🔎 **Это текстовый поиск, и он не тот, что «поиск с галочками».** Фильтры интерфейса — жанр,
> страна, год, рейтинги, качество, субтитры, сортировка — уходят в **`GET /v1/items`** вместе с
> `conditions[]` (см. выше по файлу). Здесь только `q` и сужение по полю.
>
> **PWA шлёт сюда ровно это** (снято 2026-08-16, три разных запроса):
>
> ```
> GET /v1/items/search?q=test&field=title&type=&perpage=20&page=1
> GET /v1/items/search?q=test&field=cast&type=&perpage=20&page=1
> ```
>
> `field` переключается по вкладкам (`title` / `cast`, вендор упоминает ещё `director`), `type=`
> шлётся **пустым** — значит «все типы». Ни одного `conditions[]` и ни одного фильтра сюда не
> уходило ни разу: за них отвечает `/v1/items`. Принимает ли их этот метод в принципе — по-прежнему
> неизвестно, но веб-клиент на это не рассчитывает, и нам тоже не стоит.
>
> ### ✅ `api2/v1.1/items/search` работает **без токена**
>
> Проверено 2026-08-16 своим запросом (не из PWA):
>
> ```
> GET https://api.ios-kp.store/api2/v1.1/items/search?q=test   → HTTP 200, ~107 КБ
> ```
>
> Ни `access_token`, ни заголовка авторизации — только `q`. Ответ:
> `{status, items[40], pagination{total, current, perpage: 40, total_items}}`.
>
> Элемент — краткая карточка: `id`, `type`, `title`, `year`, `cast`, `director`, `plot`, `voice`,
> `posters{small,medium,big,wide}`, `imdb`/`imdb_rating`, `kinopoisk`/`kinopoisk_rating`,
> `finished`, `advert`, `poor_quality`. **Нет** `videos`, `seasons`, `duration`, `genres`,
> `countries`, `quality`.
>
> Плюс поле, которого в v1 нет: **`value`** — готовая строка для подсказки, вида
> `"Тест / Test (2013)"`. Вместе с отсутствием авторизации это выглядит как эндпоинт
> **подсказок/автодополнения**, а не результатов: PWA дёргает его параллельно с v1-поиском.
>
> Практическая ценность для нас: **поиск, работающий до логина**. Стоит ли им пользоваться — вопрос
> открытый (второй хост, неофициальная ветка, `perpage` не пробовали).
>
> Опечатка в хосте (`api.service-kp.cnom`) — вендорская, оставлена как есть.

**Параметры запроса::**

-

**q** - Строка поиска
-

**[type]** - Типы видео контента, тип контента
-

**[field]** - поиск только в одном из полей title,director,cast. Если не указанно, поиск по всем полям.
-

**perpage** - кол-во результатов на страницу. По умолчанию 40.
-

**sectioned** - 0/1 (по умолчанию 0). Разбивает запрос по секциям type.

Ответ без sectioned:

```
HTTP/1.1 200 OK
Content-Type: application/js

{
    'status': 200,
    'items': [],
    'pagination': {},
}

```
  
Ответ c sectioned=1:

```
HTTP/1.1 200 OK
Content-Type: application/js

{
    'status': 200,
    'items': [
        'movie': [
            'items': [],
            'pagination': {},
        ],
    ],
}

```

##

Запрос:

```
GET https://api.service-kp.com/v1/items/similar

```

**Параметры запроса:**

-

**id** - Идентификатор item для которого проивзодится поиск похожих
  
**Ответ::**

Список видео

##

Запрос:

```
GET https://api.service-kp.com/v1/items/<item-id>

```

**Параметры запроса:**

-

<s>[exclude_info]</s> - 1 исключить из ответа секцию item. Опция удалена
-

**[nolinks]** - 1 исключает ссылки на видео (значение по умолчания - 0). У больших сериалов ссылки занимают львиную долю объема ответа причем большинство из этих ссылок не используется в рамках 1 запроса. В следующей версии значение по умолчанию станет 1, а через версию параметр станет недоступным и ссылки нужно будет всегда получать в отдельном запросе.

Ответ для типов movie, documovie, concert:

```
HTTP/1.1 200 OK
Content-Type: application/js

{
    'item': {
        // Набор данных из "https://api.service-kp.com/v1/items". Отсутствует, если exclude_info=1
        videos: [
            {
                'title': 'Название видео',
                'thumbnail': 'http://kino.pub/media/thumbnail/12345.jpg',
                'duration': 1234, //Время в секундах
                'watched' : 1, // Статус просмотра эпизода: -1 не смотрели вообще, 0 - начали смотреть, 1 - просмотрели
                'watching' : {
                    'status': -1, // Статус просмотра эпизода: -1 не смотрели вообще, 0 - начали смотреть, 1 - просмотрели
                    'time': 1234  // Время просмотра в секундах
                },
                'tracks': '1,2,3,4' // Номера аудио-дорожек
                'subtitles': [
                    {
                        'lang': 'eng',
                        'shift': 0, // Смещение относительно видео-потока
                        'embed': true, // Доступно в файле-исходнике, вшиты в него отдельным стримом
                        'url': 'http://url/to/file.srt',
                    }
                ],
                "audios": [
                   {
                       "id": 15510,
                       "index": 1,
                       "codec": "aac",
                       "channels": 2,
                       "lang": "ukr",
                       "type": {
                           "id": 2,
                           "title": "Многоголосый",
                           "short_title": "MVO"
                       },
                       "author": {
                           "id": 7,
                           "title": "Дохалов",
                           "short_title": null
                       }
                   },
                   {
                       "id": 15504,
                       "index": 2,
                       "codec": "aac",
                       "channels": 2,
                       "lang": "rus",
                       "type": {
                           "id": 2,
                           "title": "Многоголосый",
                           "short_title": "MVO"
                       },
                       "author": {
                           "id": 1,
                           "title": "Видеосервис",
                           "short_title": null
                       }
                   },
                   {
                       "id": 15505,
                       "index": 3,
                       "codec": "aac",
                       "channels": 2,
                       "lang": "rus",
                       "type": {
                           "id": 2,
                           "title": "Многоголосый",
                           "short_title": "MVO"
                       },
                       "author": {
                           "id": 2,
                           "title": "BD CEE",
                           "short_title": null
                       }
                   },
                   {
                       "id": 15508,
                       "index": 4,
                       "codec": "aac",
                       "channels": 2,
                       "lang": "rus",
                       "type": {
                           "id": 5,
                           "title": "Авторский",
                           "short_title": "AVO"
                       },
                       "author": {
                           "id": 4,
                           "title": "Гаврилов",
                           "short_title": null
                       }
                   },
                   {
                       "id": 15512,
                       "index": 10,
                       "codec": "ac3",
                       "channels": 6,
                       "lang": "rus",
                       "type": {
                           "id": 2,
                           "title": "Многоголосый",
                           "short_title": "MVO"
                       },
                       "author": {
                           "id": 1,
                           "title": "Видеосервис",
                           "short_title": null
                       }
                   }
                ],
                'files': [
                    {
                        'w': 720,
                        'h': 306,
                        'quality': '420p',
                        'url': {
                            'http': 'http://url/to/http/stream.mp4',
                            'hls': 'http://url/to/hls/stream/playlist.m3u8'
                        },
                    },
                    {
                        'w': 960,
                        'h': 480,
                        'quality': '720p'
                        'url': {
                            'http': 'http://url/to/http/stream.mp4',
                            'hls': 'http://url/to/hls/stream/playlist.m3u8'
                        },
                    }
                ]
            }
        ]
    },
}

```
  
Ответ для типов serial, docuserial:

```
HTTP/1.1 200 OK
Content-Type: application/js

{
    'item': {
        // Набор данных из "https://api.service-kp.com/v1/items". Отсутствует, если exclude_info=1
        seasons: [
            {
                'title': 'Название сезона',
                'number': 1,
                'episodes': [
                    {
                        'title': 'Название видео',
                        'thumbnail': 'http://kino.pub/media/thumbnail/12345.jpg',
                        'duration': 1234, //Время в секундах
                        'audios': [],
                        'files': [
                            {
                                'w': 720,
                                'h': 306,
                                'quality': '420p',
                                'url': {
                                    'http': 'http://url/to/http/stream.mp4',
                                    'hls': 'http://url/to/hls/stream/playlist.m3u8'
                                },
                            },
                            {
                                'w': 960,
                                'h': 480,
                                'quality': '720p'
                                'url': {
                                    'http': 'http://url/to/http/stream.mp4',
                                    'hls': 'http://url/to/hls/stream/playlist.m3u8'
                                },
                            }
                        ]
                    }
                ]
            }
        ]
    },
}

```

---

### 🔎 Проверено на живом ответе — `subtype: multi` (наша заметка, не вендорская)

Захвачено 2026-08-16 с `GET /v1/items/124447` («Властелины вселенной»). Копия payload'а лежит в
`Packages/KinoPubBackend/Tests/KinoPubBackendTests/Fixtures/item_124447_multi.json`, проверки — в
`MultiVersionItemTests`.

**Многосерийные фильмы и fps-версии — один и тот же механизм.** Никакого `seasons` у такого item'а
нет: «фейковые эпизоды» лежат прямо в `videos`, каждый со своими `snumber: 0` и `number: 1…n` —
это и есть нотация `s0e1` / `s0e2`. Что именно перед тобой, часть или кодировка, говорит **только
строка `title`** («24 fps» против названия части). Из структуры это не выводится.

Чего нет в примере выше, но есть в реальном ответе: у каждого элемента `videos` — свои `id`,
`number`, `snumber`, `ac3` и `files`.

| | `videos[0]` | `videos[1]` |
| --- | --- | --- |
| `id` | 1149307 | 1155958 |
| `number` / `snumber` | 1 / 0 | 2 / 0 |
| `title` | `24 fps` | `48 fps` |
| `duration` | 8634 | 8634 |
| `subtitles` | **55** | **0** |
| `watching` | `{status: 1, time: 8634}` | `{status: 1, time: 8522}` |

Следствия — каждое было живым дефектом до этого захвата:

- **Субтитры и аудио принадлежат элементу, а не фильму.** 55 против 0 на одном тайтле.
- **`duration.total` — это сумма всех элементов** (8634 + 8634). Фильм на 2 ч 24 мин показывался как
  4 ч 48 мин. Хронометраж фильма — `duration.average`.
- **`watching` тоже на элемент**, поэтому позиция возобновления между версиями бессмысленна.
- Чтение `videos.first` делает второй элемент недостижимым и подмешивает дорожки первого в
  воспроизведение второго.

**Чтобы играть конкретный вариант, ничего дополнительно запрашивать не нужно** — у элемента уже
есть свои `files`. Меняется только то, что отправляем обратно: `id` — фильма, `video` — `number`
элемента, `season` — `nil`.

**Расхождение с документацией выше:** здесь `tracks` описан как строка `'1,2,3,4'`, а в ответе
приходит числом (`tracks: 4`).

### 🔎 Проверено — концерт (`type: "concert"`), item 126187

Фикстура `item_126187_concert.json`, тесты `ConcertItemTests`.

`tracklist` — форма `{artists, title, url}`. На живом концерте **`artists` и `url` пустые у всех
шести треков**, а неизвестный трек называется буквально `"N/A"`. Рассчитывать можно только на
`title`, и `"N/A"` придётся отфильтровывать.

🔴 **`tracklist` мы не декодируем вообще** — `MediaItem` его не знает, сетлист теряется. Тест
`ConcertItemTests.testTracklistIsNotDecodedYet` держит гэп зафиксированным и упадёт, когда поле
появится.

Остальное с того же ответа:

- **`imdb: null` при `imdb_rating: 8.1`** (и так же `kinopoisk`). Рейтинг существует без id —
  переход «есть рейтинг, значит есть внешний id» невозможен.
- `subtype: ""` — пустая строка, не `null` и не отсутствие ключа.
- `trailer: null`, `voice: null`.
- `audios[].author: null` на оригинальной дорожке — поле заполняется только у дубляжей.
- `videos[0].title: "Концерт"` — одна запись с названием, а не список номеров.
- `director: "Мартин Скорсезе"` на концерте Schiller. **Данные источника бывают мусорными**, логику
  на осмысленности поля не строить.

### 🔎 `api2/v1.1/items/{id}` отдаёт поля, которых в v1 нет

Снято 2026-08-16 с `https://api.ios-kp.store/api2/v1.1/items/4368`, нами не проверено.

```json
{ "item": { "id": 4368, "title": "Футурама - Потерянное приключение / …",
            "age_rating": -1, "fps": 29.97,
            "imdb": 1253575, "imdb_rating": 6.7,
            "kinopoisk": 418859, "kinopoisk_rating": 6.72 }, "status": 200 }
```

Ответ урезанный — ни `videos`, ни жанров, ни постеров. Но в нём есть два поля, которых в v1 нет:

- **`age_rating`** — возрастной рейтинг от самого kino.pub. Сейчас мы берём его только из TMDB
  (`externalMetadata.ageRating`). `-1`, судя по всему, «неизвестно».
- **`fps`** — на многоверсионном айтеме (24/48 fps) **не смотрели**; возможно, это поле верхнего
  уровня и там оно бессмысленно.

Похоже на дешёвый эндпоинт для дозапроса пары полей. Стоит ли ради него ходить на второй хост —
открытый вопрос.

##

Внимание, поле status больше не используется в успешных ответах.

Запрос:

```
GET https://api.service-kp.com/v1/items/media-links?mid=<media_id>

```

**Параметры запроса:**

-

**mid** - Идентификатор media

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/js

    {
            "files": [
                    {
                            "codec": "h264",
                            "w": 1920,
                            "h": 1080,
                            "quality": "1080p",
                            "quality_id": 3,
                            "file": "/b/8c/diBAgF24FkaNBwPpB.mp4",
                            "urls": {
                                    "http": "https://host/token/file.mp4",
                                    "hls": "https://host/token/file.mp4",
                                    "hls4": "https://host/token/file.mp4",
                                    "hls2": "https://host/token/file.mp4"
                            }
                    },
                    {
                            "codec": "h264",
                            "w": 1280,
                            "h": 720,
                            "quality": "720p",
                            "quality_id": 2,
                            "file": "/7/b3/5qx0TBPotyBf0nsrZ.mp4",
                            "urls": {
                                    "http": "https://host/token/file.mp4",
                                    "hls": "https://host/token/file.mp4",
                                    "hls4": "https://host/token/file.mp4",
                                    "hls2": "https://host/token/file.mp4"
                            }
                    },
            ],
            "subtitles": [
                    {
                            "lang": "eng",
                            "shift": 0,
                            "embed": true,
                            "file": "/a/71/29725.srt",
                            "url": "https://host/token/file.srt"
                    },
                    {
                            "lang": "rus",
                            "shift": 0,
                            "embed": true,
                            "file": "/2/2a/29859.srt",
                            "url": "https://host/token/file.srt"
                    }
            ]
    }

```

##

Внимание, поле status больше не используется в успешных ответах.

Запрос:

```
GET https://api.service-kp.com/v1/items/media-video-link?file=/path/to/file&type=http

```

**Параметры запроса:**

-

**file** - Путь к файлу
-

**type** - Тип потока, http|hls|hls2|hls4

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/js

    {
            "url": "https://host/hls4/client/token/path/to/file.mp4?loc=de"
    }

```

##

Запрос:

```
GET https://api.service-kp.com/v1/items/vote?id=111&like=1

```

**Параметры запроса:**

-

**id** - идентификатор item
-

**like** - 1: нравится, 0: не нравится

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/js

    {
    "voted": true, // засчитался ли голос
    "total": "5", // всего голосов
    "positive": "5", // позитивных голосов
    "negative": "0", // негативных голосов
    "rating": 5 // подсчитанный рейтинг: позитивные минус негативные
    }

```

##

Запрос:

```
GET https://api.service-kp.com/v1/items/comments?id=<item_id>

```

**Параметры запроса:**

-

**id** - Идентификатор фильма/сериала/etc

Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/js

{
    "status":200,
    "item" : {
        "id":1235,
        "title":"Книга крови /  Book of Blood"
    },
    "comments":[
       {
           "id":1,
           "depth":0,
           "unread":false,
           "deleted":false,
           "message":"comment message",
           "created":1234234234,
           "rating":"0",
           "user":{
               "id":123,
               "name":"UserName",
               "avatar":"http://gravatar.com/avatar/asdasdasdas"
            }
        },
     ]
 }

```

##

Запрос:

```
GET https://api.service-kp.com/v1/items/trailer?[id=123 | sid=l_5JsdfkjN34]

```
  
Ответ:

```
HTTP/1.1 200 OK
Content-Type: application/js

[
    {
        'status': 200,
        'trailer': {
            'id': 'l_54Jsdfkn',
            'url': 'http://youtube.com/watch?v=l_54Jsdfkn',
            'files': [
                {
                    'url': 'https://url.to.file',
                    'quality': 360,
                    'width: 480,
                    'height': 360,
                },
            ],
        }
    }
]

```

##

Запрос:

```
GET https://api.service-kp.com/v1/items/fresh

```

**Параметры запроса:**

-

**type** - Типы видео контента
-

**[page=0]** - текущая страница
-

**[perpage=25]** - количество на страницу
  
**Ответ::**

Видео контент

##

Запрос:

```
GET https://api.service-kp.com/v1/items/hot

```

**Параметры запроса:**

-

**type** - Типы видео контента
-

**[page=0]** - текущая страница
-

**[perpage=25]** - количество на страницу
  
**Ответ::**

Видео контент

##

Запрос:

```
GET https://api.service-kp.com/v1/items/popular

```

**Параметры запроса:**

-

**type** - Типы видео контента
-

**[page=0]** - текущая страница
-

**[perpage=25]** - количество на страницу
  
**Ответ::**

Видео контент

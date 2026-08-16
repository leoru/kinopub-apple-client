Справочники — API 1.3 3 documentation

> 🔎 **Всё это разом лежит в одном публичном файле — `https://www.kpapp.link/config.json`.**
> Снято 2026-08-16 (`version: 2.12.7`, ~26 КБ). **Без авторизации** — токен не нужен вообще, что
> делает его пригодным ещё до логина. Нами не проверено дальше однократного скачивания: как часто
> меняется, есть ли ETag/кэш-заголовки, что означает `version` — неизвестно.
>
> | Ключ | Что внутри |
> | --- | --- |
> | `filter.types` | 7 типов: `movie`, `serial`, `documovie`, `docuserial`, `concert`, `tvshow`, `3d`. У каждого поле `genres` — **какой набор жанров к нему применим** (`movie` / `docu` / `tvshow` / `music`) |
> | `filter.genres` | Жанры по четырём наборам: movie 30, docu 46, tvshow 7, music 31 |
> | `filter.countries` | 102 страны, `{id, title}` |
> | `filter.sort` | 9 сортировок: `updated`, `year`, `title`, `created`, `rating`, `kinopoisk_rating`, `imdb_rating`, `views`, `watchers` |
> | `filter.subtitles` | 24 языка субтитров |
> | `sections` | 11 разделов меню: movie, serial, concert, cartoon, multserial, anime, documovie, docuserial, tvshow, 3d, standup |
> | `home_blocks` | 11 блоков главной — `{title, type, genre_id, section}` |
> | `home_blocks_shortcut` | 12 быстрых блоков — `{title, mode, type, section}`, где `mode` ∈ `hot` / `popular` |
> | `quality_list` / `quality_list_w` | `2160→4K`, `1080→FHD`, `720→HD`, `480→SD` (+`auto`); `_w` — та же таблица по ширине: 3840/1920/1280/720 |
> | `default_settings` | Дефолты клиента: `app` (зеркало, стартовый экран), `menu` (какие разделы показывать), `list`, `card` (показывать ли похожие, подборки, режиссёра), `play`, `theme` |
>
> **Почему это важно нам:** `home_blocks_shortcut` — это ровно тот «spec, carrying type + sort», в
> который по ROADMAP должен превратиться захардкоженный `HomeCatalog.Shortcut`. И жанры с типами
> связаны **не** «все жанры ко всем типам»: `filter.types[].genres` говорит, какой набор показывать.
>
> **Осторожно:** `default_settings.app.mirror` — это зеркало, а `type: "pwa"`. То есть файл описывает
> *веб-клиент*, и часть дефолтов к нашим платформам отношения не имеет. Брать оттуда справочники, а
> не поведение.

#
  
Содержание  
-

Справочники  
  -

Список локаций сервера
  -

Список типов стриминга
  -

Список типов переводов
  -

Список авторов озвучек/переводов
  -

Список качеств видео
  
##

Запрос:

```
GET https://api.service-kp.com/v1/references/server-location

HTTP/1.1 200 OK
Content-Type: application/json

{
  'status': 200,
  'items': [
     {
        'id': 1,
        'location': 'de',
        'name': 'Германия',
     }
  ],
}

```

##

Запрос:

```
GET https://api.service-kp.com/v1/references/streaming-type

HTTP/1.1 200 OK
Content-Type: application/json

{
  'status': 200,
  'items': [
     {
        'id': 1,
        'code': 'hls4',
        'name': 'HLS4',
        'description': 'Description'
     }
  ],
}

```

##

Запрос:

```
GET https://api.service-kp.com/v1/references/voiceover-type

HTTP/1.1 200 OK
Content-Type: application/json

{
  'status': 200,
  'items': [
     {
        "id": 1,
        "title": "Дубляж",
        "short_title": "DUB"
     },
  ],
}

```

##

Запрос:

```
GET https://api.service-kp.com/v1/references/voiceover-author

HTTP/1.1 200 OK
Content-Type: application/json

{
  'status': 200,
  'items': [
     {
        "id": 1,
        "title": "Видеосервис",
        "short_title": null
     },
  ],
}

```

##

Запрос:

```
GET https://api.service-kp.com/v1/references/video-quality

HTTP/1.1 200 OK
Content-Type: application/json

{
  'status': 200,
  'items': [
     {
        "id": 1,
        "title": "480p",
        "quality": 480,
     },
     {
        "id": 2,
        "title": "720p",
        "quality": 720,
     },
  ],
}

```

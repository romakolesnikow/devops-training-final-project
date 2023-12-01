# bingo app

Сочинение на тему "Как я это разворачивал" в папке `/materials` в файле `report.md`

На момент 23:30 01.12.2023 сервис доступен по адресу http://158.160.130.208/. Сервис развернут на бесплатном гранте в Yandex.Cloud и я не уверен когда его отключат)
В окончательном варианте было принято решение не делать кэширование и https с nginx, т.к. оно ломало тесты на отказоустойчивость и я не успел подтюнить машину с прокси.

# Установка

## Требования

На вашем компьютере должны быть установлены `docker`, `terraform`.

Моя инсталляция частично описана с помощью Terraform для авторазвёртывания в облаке, но не автоматизирована полностью. 
То, что хотел, но не успел автоматизировать:
* Настраивание часов на виртуалках
* Создание индексов в базе данных для ускорения отдачи нужных эндпоинтов
* Reverse-proxy на nginx с настройками кэширования и https
* Автоустановка скрипта для более хорошей отказоустойчивости сервиса

Для установки в Yandex.Cloud на своём аккаунте нужно учесть необходимость создания своего сервисного аккаунта, настройки своего `folder-id` и ssh-ключа в файле main.tf.

Для установки на одной ноде в Yandex.Cloud см. `/materials/examples/one_node.tf`

Для установки сервиса локально см. папку `bingo`

Для упрощения сборки образа для виртуалок и пуша их в Container registry был написан скрипт `push_img_to_registry.sh` в папке `terraform`

## Установка времени

Не уверен насчет необходимости настройки времени на всех виртуалках, но на прокси-сервере обязательно:

```bash
sudo timedatectl set-timezone "Europe/Moscow"
```


## Nginx proxy

Прокси сервер сам создается с помощью Terraform, но самоподписанный сертификат нужно создать руками.

```bash
sudo openssl genpkey -algorithm RSA -out private.key
sudo openssl req -new -key private.key -out certificate.csr
sudo openssl req -x509 -key private.key -in certificate.csr -out certificate.crt -days 365
```
также нужно положить в nginx необходимые конфигурационные файлы (путь в проекте: /terraform/nginx/configs)

## Тюнинг в postgresql

нужно зайти в базу любыми подручными средствами, для подключения я использовал pgAdmin и выполнить нижеописанные запросы:

```sql
CREATE INDEX idx_sessions_customer_id ON sessions (customer_id);

CREATE INDEX idx_sessions_movie_id ON sessions (movie_id);

CREATE INDEX idx_movies_year ON movies (year);

CREATE INDEX idx_movies_name ON movies (name);

CREATE INDEX idx_customers_id ON customers (id);

CREATE INDEX idx_movies_id ON movies (id);
```
## Установка скрипта на каждую ноду

Скрипт лежит в каталоге `/bingo` под именем `check.sh`. У приложения есть такая болячка, что после определенной нагрузки он может выдавать на `/ping` 500 Internal Server Error, но при этом быть запущен. Этот скрипт проверяет каждые 2 секунды `/ping` и в случае 500 рестартит контейнер.

Загружаем на уже поднятые виртуалки с приложением скрипт `check.sh` любыми доступными методами (можно использовать scp)

Пример:
`scp -i ~/.ssh/your_ssh_key check.sh alpine@62.351.53.64:/home/alpine`

Подключаемся на машину с приложением:
`ssh -i ~/.ssh/your_ssh_key alpine@62.351.53.64`

Устанавливаем фоновый запуск любым предпочтительным способом:

1. Через crontab (Не желательный способ, долгое восстановление ноды):
Вводим `crontab -e`. Вставляем туда строку `* * * * * /home/alpine/check.sh`. Подтверждаем сохранение.

2. Через tmux
Вводим комманду `tmux`. Запускаем скрипт `sh /home/alpine/check.sh`. Выходим из tmux с помощью комбинации клавиш `Ctrl + B` и `D`.

3. Через nohup
`nohup /home/alpine/check.sh > /dev/null 2>&1 &`.

# Как помочь проекту / Contributing

Спасибо, что заглянули! Любая помощь приветствуется — от идеи в одну строку до пулл-реквеста.
*Thanks for stopping by! Any help is welcome — from a one-line idea to a pull request. English is fine.*

## Идеи и вопросы / Ideas and questions

- Предложить идею или задать вопрос — вкладка **Discussions** или **Issues → «Идея»**.
- Нашли ошибку — **Issues → «Ошибка»**: что сделали, что ожидали, что получилось.

## ⚠️ Уязвимости / Security issues

Бот работает с личными переписками. Если нашли уязвимость (обход подтверждения, утечку данных,
способ заставить бота отправить что-то от имени владельца) — **не публикуйте детали в открытом Issue**.
Используйте **Security → Report a vulnerability** в этом репозитории.

*Found a vulnerability? Please report it privately via **Security → Report a vulnerability**, not in a public issue.*

## Пулл-реквесты / Pull requests

1. Сделайте форк и ветку от `main`.
2. Изменения в серверной логике — в `plugin/server.ts`, помечайте их комментарием `[custom]`.
3. Обновите патч: `diff -u --strip-trailing-cr <оригинальный server.ts> plugin/server.ts > patches/telegram-0.0.7-business.patch`.
4. Проверьте, что код собирается: `bun build plugin/server.ts --target=bun --outdir=dist`.
5. **Никаких личных данных**: токенов, ID, имён, переписок, скриншотов с незакрытыми именами.
6. Опишите в PR, что и зачем изменено и как вы это проверили.

## Где особенно нужна помощь / Good places to start

- тесты для лимитов, истории и черновиков;
- автозапуск для macOS и Linux;
- распознавание голосовых сообщений;
- скрипт для переноса патча на новые версии плагина.

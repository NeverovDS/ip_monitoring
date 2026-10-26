---
name: add-api-endpoint
description: Add a JSON endpoint under /api/v1 in ip_monitoring without breaking the existing API contract. Use when the task is a new API route, action or response.
argument-hint: "[what the endpoint should do]"
---

Add this endpoint: $ARGUMENTS

Follow the existing pattern exactly. Read these first:
`config/routes.rb`, `app/controllers/api/v1/base_controller.rb`,
`app/controllers/api/v1/ips_controller.rb`, `app/serializers/base_serializer.rb`,
`app/serializers/ip_serializer.rb`, `test/integration/api_v1_ips_test.rb`.

1. **Route.** Add it inside `namespace :api do namespace :v1 do ... end end`. A per-IP action
   is a `member` route; a list-level one is a `collection` route. Do not touch the HTML
   `resources :ips` block unless the UI needs the same action.
2. **Controller action** in `Api::V1::IpsController` (or a new controller that inherits
   `Api::V1::BaseController`, so Basic auth and `rescue_from` apply). Load the record with
   `set_ip`; `RecordNotFound` already becomes a 404 JSON error.
3. **Params** are top-level, as in `ip_params`. Never nest them under `:ip`.
4. **Logic** that is more than a lookup goes into a model scope/class method or an
   `app/services` object, not into the action.
5. **Response** through a serializer: reuse one or add `app/serializers/<name>_serializer.rb`
   inheriting `BaseSerializer` and implementing `serialize`. **Errors** only via
   `render_error(code, message, status:)`: `:validation_error` with
   `:unprocessable_content`, `:not_found`, `:bad_request`.
6. **Tests** in `test/integration/api_v1_ips_test.rb`: the auth requirement, the happy path,
   the 404, and every validation error. Delegate to the `test-writer` subagent if the
   change is large.
7. **Docs.** Add a row to the API table in `README.md`.
8. Run `bin/rails test test/integration/api_v1_ips_test.rb`, then ask the `code-reviewer`
   subagent to review the diff. RuboCop and the full suite run when you commit.

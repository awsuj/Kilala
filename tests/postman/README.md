# Postman Collections for Project Kilala API Testing

This directory holds the automated API test collections used by GitHub Actions CI via **Newman**.

## How to Add or Update QA Test Collections:
1. In Postman, right-click the collection -> **Export** -> **Collection v2.1 (recommended)**.
2. Save the `.json` file in this directory (`tests/postman/`), ending with `.postman_collection.json`.
3. If using an environment file (e.g. for `baseUrl`, auth tokens), export it as `.postman_environment.json`.
4. Commit and push:
   ```bash
   git add tests/postman/
   git commit -m "test(api): update postman collection"
   git push
   ```
GitHub Actions will automatically pick up and execute all `.postman_collection.json` files during **Phase 5 (Integration Testing)**.

## Running Locally:
Make sure the backend is running (`cd backend && npm run dev` on port 5001), then run:
```bash
npx newman run tests/postman/kilala-api.postman_collection.json
```

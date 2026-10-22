import path from 'path';
import express from 'express';
import cookieParser from 'cookie-parser';
import { config } from './config';
import { loadUser } from './middleware/auth';
import authRoutes from './routes/auth';
import portalRoutes from './routes/portal';

const app = express();

// Views (EJS) + static assets live one level up from the compiled src/.
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '..', 'views'));
app.use(express.static(path.join(__dirname, '..', 'public')));

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(cookieParser());
app.use(loadUser);

app.use('/', authRoutes);
app.use('/', portalRoutes);

app.listen(config.port, () => {
  console.log(`[web-lgu]: Kilala LGU Portal running on http://localhost:${config.port}`);
  console.log(`[web-lgu]: talking to backend at ${config.apiBaseUrl}`);
});

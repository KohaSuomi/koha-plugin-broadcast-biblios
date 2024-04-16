// Description: Vue.js application for configuring the plugin
const { createApp } = Vue
const { createPinia } = Pinia;
const { createI18n } = VueI18n;
import configComponent from "./components/config-component.js";
import userComponent from "./components/user-component.js";
import recordComponent from "./components/record-component.js";
import { messages } from "./helpers/translations.js";

const i18n = createI18n({
  locale: 'fi', // set locale
  fallbackLocale: 'en', // set fallback locale
  messages, // set locale translations
});

const app = createApp({});
app.component('config-component', configComponent);
app.component('user-component', userComponent);
app.component('record-component', recordComponent);
const pinia = createPinia();
app.use(pinia);
app.use(i18n);
app.mount('#broadcastApp');

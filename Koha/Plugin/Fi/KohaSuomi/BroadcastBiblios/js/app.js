// Description: Vue.js application for configuring the plugin
const { createApp } = Vue
const { createPinia } = Pinia;
import configComponent from "./components/config-component.js";
import userComponent from "./components/user-component.js";
import recordComponent from "./components/record-component.js";
import { setLang } from './helpers/translations.js';

// Set language based on browser or user preference
const browserLang = (pageLang || navigator.language || navigator.userLanguage || 'en').substring(0,2);
setLang(['en', 'fi', 'sv'].includes(browserLang) ? browserLang : 'en');

const app = createApp({});
app.component('config-component', configComponent);
app.component('user-component', userComponent);
app.component('record-component', recordComponent);
const pinia = createPinia();
app.use(pinia);
app.mount('#broadcastApp');

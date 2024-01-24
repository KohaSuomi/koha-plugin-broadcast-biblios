// Description: Vue.js application for configuring the plugin
const { createApp } = Vue
const { createPinia } = Pinia;
import configComponent from "./components/config-component.js";

const app = createApp({});
app.component('config-component', configComponent);
const pinia = createPinia();
app.use(pinia);
app.mount('#configApp');

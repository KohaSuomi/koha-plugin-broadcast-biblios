// Description: Vue.js application for configuring the plugin
const { createApp } = Vue
const { createPinia } = Pinia;
import configComponent from "./components/config-component.js";
import userComponent from "./components/user-component.js";
import recordComponent from "./components/record-component.js";

const app = createApp({});
app.component('config-component', configComponent);
app.component('user-component', userComponent);
app.component('record-component', recordComponent);
const pinia = createPinia();
app.use(pinia);
app.mount('#broadcastApp');

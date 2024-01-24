const { defineStore } = Pinia;
const { ref, computed } = Vue;

export const useErrorStore = defineStore('error', {
    state: () => ({
        errors: ref([]),
    }),
    actions: {
        setError(error) {
            if (error.message) {
                this.errors.push(error.message);
            } else {
                this.errors.push(error);
            }
            if (error.response.data.error) {
                this.errors.push(error.response.data.error);
            }
        },
        clearError() {
            this.errors = [];
        },
    },
});
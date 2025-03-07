<script>
  import { mapMutations } from 'vuex'
  import { validationMixin } from 'vuelidate'
  import { basicInfoValidations, validationMessages } from './common/signUpValidations'
  import SecondaryButton from '../../teacher-dashboard/common/buttons/SecondaryButton'

  export default {
    metaInfo: {
      meta: [{ vmid: 'viewport', name: 'viewport', content: 'width=device-width, initial-scale=1' }]
    },
    components: {
      SecondaryButton
    },
    mixins: [validationMixin],
    data: () => {
      const url = new URLSearchParams(window.location.search)
      return {
        firstName: url.get('firstName') || '',
        lastName: url.get('lastName') || '',
        email: url.get('email') || '',
        password: '',
        passwordFieldType: 'password',
        validationMessages: validationMessages
      }
    },

    validations: basicInfoValidations,

    computed: {
      isFormValid () {
        return !this.$v.$invalid
      }
    },

    watch: {
      isFormValid (val) {
        this.$emit('validityChange', val)
      }
    },

    methods: {
      ...mapMutations({
        updateSignupForm: 'teacherSignup/updateSignupForm',
        updateTrialRequestProperties: 'teacherSignup/updateTrialRequestProperties'
      }),

      onChangeValue (event) {
        const attrs = {}
        attrs[event.target.name] = event.target.value
        this.updateSignupForm(attrs)
        if (event.target.name !== 'password') {
          this.updateTrialRequestProperties(attrs)
        }
      },
      togglePassword () {
        this.passwordFieldType = this.passwordFieldType === "password" ? "text" : "password";
        this.$refs.password.focus();
      },

      onClickNext () {
        if (this.isFormValid) {
          this.$emit('goToNext')
        }
      }
    }
  }
</script>

<template lang="pug">
  #basic-info-component.page-educator-signup-component
    form.form-container(@submit.prevent="onClickNext")
      .first-name.form-group.row(:class="{ 'has-error': $v.firstName.$error }")
        .col-sm-8.col-xs-12
          span.inline-flex-form-label-div
            span.control-label {{ $t("general.first_name") }}
            span.form-error(v-if="!$v.firstName.required") {{ $t(validationMessages.errorRequired.i18n) }}
          input#first-name-input.form-control(name="firstName" v-model="$v.firstName.$model" @change="onChangeValue($event)")
      .last-name.form-group.row(:class="{ 'has-error': $v.lastName.$error }")
        .col-sm-8.col-xs-12
          span.inline-flex-form-label-div
            span.control-label {{ $t("general.last_name") }}
            span.form-error(v-if="!$v.lastName.required") {{ $t(validationMessages.errorRequired.i18n) }}
          input#last-name-input.form-control(name="lastName" v-model="$v.lastName.$model" @change="onChangeValue($event)")
      .email.form-group.row(:class="{ 'has-error': $v.email.$error }")
        .col-sm-8.col-xs-12
          span.inline-flex-form-label-div
            span.control-label {{ $t("general.email") }}
            span.form-error(v-if="!$v.email.required") {{ $t(validationMessages.errorRequired.i18n) }}
            span.form-error(v-if="!$v.email.email") {{ $t(validationMessages.errorInvalidEmail.i18n) }}
            span.form-error(v-else-if="!$v.email.uniqueEmail") {{ $t(validationMessages.errorEmailExists.i18n) }}
          input#email-input.form-control(name="email" v-model="$v.email.$model" type="email" @change="onChangeValue($event)")
      .password.form-group.row(:class="{ 'has-error': $v.password.$error }")
        .col-sm-8.col-xs-12
          span.inline-flex-form-label-div
            span.control-label {{ $t("general.password") }}
            span.form-error(v-if="!$v.password.required") {{ $t(validationMessages.errorRequired.i18n) }}
            span.form-error(v-else-if="$v.password.$error") {{ $t('signup.invalid') }}
          input#password-input.form-control(name="password" ref="password" :type="passwordFieldType" v-model="$v.password.$model" type="password" @change="onChangeValue($event)")
          span.password-toggle.input-group-btn.form-control
            span.btn.btn-default.reveal(@click="togglePassword")
              i.glyphicon.glyphicon-eye-open(v-if="passwordFieldType === 'password'")
              i.glyphicon.glyphicon-eye-close(v-if="passwordFieldType === 'text'")
          small.form-text.text-muted {{ $t("signup.password_requirements") }}
      .buttons.form-group.row
        .col-xs-offset-5
          secondary-button(type="submit", :inactive="!isFormValid") {{ $t("common.next") }}
</template>

<style lang="sass" scoped>
#basic-info-component
  .form-container
    #password-input
      width: calc(100% - 39px)
    .password-toggle
      width: auto
      padding: 0
      position: absolute
      right: 15px
      top: 29px
    .buttons
      margin-top: 30px
      button
        width: 150px
        height: 35px
</style>

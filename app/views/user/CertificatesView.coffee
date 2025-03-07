require('app/styles/user/certificates-view.sass')
RootView = require 'views/core/RootView'
User = require 'models/User'
Classroom = require 'models/Classroom'
Course = require 'models/Course'
CourseInstance = require 'models/CourseInstance'
Campaign = require 'models/Campaign'
LevelSessions = require 'collections/LevelSessions'
Levels = require 'collections/Levels'
ThangTypeConstants = require 'lib/ThangTypeConstants'
ThangType = require 'models/ThangType'
utils = require 'core/utils'
fetchJson = require 'core/api/fetch-json'
locale = require 'locale/locale'

module.exports = class CertificatesView extends RootView
  id: 'certificates-view'
  template: require 'app/templates/user/certificates-view'

  events:
    'click .print-btn': 'onClickPrintButton'
    'click .toggle-btn': 'onClickToggleButton'

  getTitle: ->
    return 'Certificate' if @user.broadName() is 'Anonymous'
    "Certificate: #{@user.broadName()}"

  hashString: (str) ->
    (str.charCodeAt i for i in [0...str.length]).reduce(((hash, char) -> ((hash << 5) + hash) + char), 5381)  # hash * 33 + c

  initialize: (options, @userID) ->
    @utils = utils
    if @userID is me.id
      @user = me
      if utils.isCodeCombat
        @setHero()
    else
      @user = new User _id: @userID
      @user.fetch()
      @supermodel.trackModel @user
      if utils.isCodeCombat
        @listenToOnce @user, 'sync', => @setHero?()
      @user.fetchNameForClassmate success: (data) =>
        @studentName = User.broadName(data)
        @render?()
    if classroomID = utils.getQueryVariable 'class'
      @classroom = new Classroom _id: classroomID
      @classroom.fetch()
      @supermodel.trackModel @classroom
      @listenToOnce @classroom, 'sync', @onClassroomLoaded
    if courseID = utils.getQueryVariable 'course'
      @course = new Course _id: courseID
      @course.fetch()
      @supermodel.trackModel @course
    if campaignId = utils.getQueryVariable 'campaign-id'
      @campaign = new Campaign _id: campaignId
      @campaign.fetch()
      @supermodel.trackModel @campaign
    @courseInstanceID = utils.getQueryVariable 'course-instance'
    # TODO: anonymous loading of classrooms and courses with just enough info to generate cert, or cert route on server
    # TODO: handle when we don't have classroom & course
    # TODO: add a check here that the course is completed

    @sessions = new LevelSessions()
    if @courseInstanceID
      @supermodel.trackRequest @sessions.fetchForCourseInstance @courseInstanceID, userID: @userID, data: { project: 'state.complete,level.original,playtime,changed,code,codeLanguage,team' }
      @listenToOnce @sessions, 'sync', @calculateStats
    else if campaignId
      @supermodel.trackRequest @sessions.fetchForCampaign campaignId, data: { userId: @userID, noLanguageFilter: true }
      @listenToOnce @sessions, 'sync', @calculateCampaignStats
    @courseLevels = new Levels()
    if classroomID and courseID
      @supermodel.trackRequest @courseLevels.fetchForClassroomAndCourse classroomID, courseID, data: { project: 'concepts,practice,assessment,primerLanguage,type,slug,name,original,description,shareable,i18n,thangs.id,thangs.components.config.programmableMethods' }
      @listenToOnce @courseLevels, 'sync', @calculateStats

    tenbillion = 10000000
    nintybillion = 90000000
    if features?.chinaUx
      @certificateNumber =   # keep only 8 digits
        ((@hashString(@user.id + @courseInstanceID) % nintybillion) + nintybillion) % nintybillion + tenbillion   # 10000000 ~ 99999999

    @currentLang = me.get('preferredLanguage', true)
    @needLanguageToggle = @currentLang.split('-')[0] != 'en'


  setHero: (heroOriginal=null) ->
    heroOriginal ||= utils.getQueryVariable('hero') or @user.get('heroConfig')?.thangType or ThangTypeConstants.heroes.captain
    @thangType = new ThangType()
    @supermodel.trackRequest @thangType.fetchLatestVersion(heroOriginal, {data: {project:'slug,version,original,extendedName,heroClass'}})
    @thangType.once 'sync', (thangType) =>
      if @thangType.get('heroClass') isnt 'Warrior'
        # We only have basic warrior poses and signatures for now
        @setHero ThangTypeConstants.heroes.captain

  onClassroomLoaded: ->
    @calculateStats()
    if me.id is @classroom.get('ownerID')
      @teacherName = me.broadName()
    else
      teacherUser = new User _id: @classroom.get('ownerID')
      teacherUser.fetchNameForClassmate success: (data) =>
        @teacherName = User.broadName(data)
        @render?()

  getCodeLanguageName: ->
    return 'Code' unless @classroom
    if @course and /web-dev-1/.test @course.get('slug')
      return 'HTML/CSS'
    if @course and /web-dev/.test @course.get('slug')
      return 'HTML/CSS/JS'
    return @classroom.capitalizeLanguageName()

  calculateStats: ->
    return unless @classroom.loaded and @sessions.loaded and @courseLevels.loaded
    @courseStats = @classroom.statsForSessions @sessions, @course.id, @courseLevels

    if @courseStats.levels.project
      projectSession = @sessions.find (session) => session.get('level').original is @courseStats.levels.project.get('original')
      if projectSession
        @projectLink = "#{window.location.origin}/play/#{@courseStats.levels.project.get('type')}-level/#{projectSession.id}"
        fetchJson('/db/level.session/short-link', method: 'POST', json: {url: @projectLink}).then (response) =>
          @projectShortLink = response.shortLink
          @render()

  calculateCampaignStats: ->
    return unless @sessions
    @courseStats = {}
    levelCompleteNum = 0
    linesOfCode = 0
    for session in @sessions?.models
      levelCompleteNum += (session.get('state').complete ? 1 : 0)

      # use session.countOriginalLinesOfCode to count later
      code = session.get('code')
      codeStr = code['hero-placeholder-1']?.plan || code['hero-placeholder']?.plan
      lines = (codeStr || '').split(/\n+/).length
      linesOfCode += if (lines > 1) then (lines - 1) else 0

    @courseStats = {
      levels: {
        numDone: levelCompleteNum
      },
      linesOfCode: linesOfCode
    }
    @campaignConcepts = _.map @campaign.get('description')?.split(','), (c) => c.trim()
    @render()

  onClickPrintButton: ->
    window.print()

  onClickToggleButton: ->
    newLang = 'en'
    if @currentLang.split('-')[0] == 'en'
      newLang = me.get('preferredLanguage', true)
    @currentLang = newLang
    $.i18n.changeLanguage newLang, =>
      locale.load(newLang).then =>
        @render()


  afterRender: ->
    @autoSizeText '.student-name'

  autoSizeText: (selector) ->
    @$(selector).each (index, el) ->
      while el.scrollWidth > el.offsetWidth or el.scrollHeight > el.offsetHeight
        newFontSize = (parseFloat($(el).css('font-size').slice(0, -2)) * 0.95) + 'px'
        $(el).css('font-size', newFontSize)

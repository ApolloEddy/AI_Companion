/// UI 文本强类型配置
/// 对应 assets/settings/ui_strings.yaml
class UiStringsConfig {
  final SettingsScreenStrings settingsScreen;
  final SuccessDialogStrings successDialog;
  final MainScreenStrings mainScreen;
  final CommonStrings common;

  const UiStringsConfig({
    this.settingsScreen = const SettingsScreenStrings(),
    this.successDialog = const SuccessDialogStrings(),
    this.mainScreen = const MainScreenStrings(),
    this.common = const CommonStrings(),
  });

  factory UiStringsConfig.fromYaml(Map<String, dynamic> yaml) {
    return UiStringsConfig(
      settingsScreen: SettingsScreenStrings.fromYaml(yaml['settings_screen'] ?? {}),
      successDialog: SuccessDialogStrings.fromYaml(yaml['success_dialog'] ?? {}),
      mainScreen: MainScreenStrings.fromYaml(yaml['main_screen'] ?? {}),
      common: CommonStrings.fromYaml(yaml['common'] ?? {}),
    );
  }
}

class SettingsScreenStrings {
  final String appearanceTitle;
  final String coreModelTitle;
  final String userProfileTitle;
  final String aiIdentityTitle;
  final String dataManagementTitle;
  final String dangerZoneTitle;
  final String genderMale;
  final String genderFemale;
  final String genderOther;
  final String saveProfile;
  final String exportChat;
  final String factoryReset;
  final String apiKeyHint;
  final String nicknameHint;

  const SettingsScreenStrings({
    this.appearanceTitle = '外观 (APPEARANCE)',
    this.coreModelTitle = '核心模型 (CORE MODEL)',
    this.userProfileTitle = '用户画像 (USER PROFILE)',
    this.aiIdentityTitle = 'AI 身份 (AI IDENTITY)',
    this.dataManagementTitle = '数据管理 (DATA MANAGEMENT)',
    this.dangerZoneTitle = '危险区域 (DANGER ZONE)',
    this.genderMale = '男性',
    this.genderFemale = '女性',
    this.genderOther = '其他',
    this.saveProfile = '保存画像',
    this.exportChat = '导出聊天记录',
    this.factoryReset = '恢复出厂设置',
    this.apiKeyHint = '请输入 API Key',
    this.nicknameHint = '您的昵称',
  });

  factory SettingsScreenStrings.fromYaml(Map<String, dynamic> yaml) {
    return SettingsScreenStrings(
      appearanceTitle: yaml['appearance_title']?.toString() ?? '外观 (APPEARANCE)',
      coreModelTitle: yaml['core_model_title']?.toString() ?? '核心模型 (CORE MODEL)',
      userProfileTitle: yaml['user_profile_title']?.toString() ?? '用户画像 (USER PROFILE)',
      aiIdentityTitle: yaml['ai_identity_title']?.toString() ?? 'AI 身份 (AI IDENTITY)',
      dataManagementTitle: yaml['data_management_title']?.toString() ?? '数据管理 (DATA MANAGEMENT)',
      dangerZoneTitle: yaml['danger_zone_title']?.toString() ?? '危险区域 (DANGER ZONE)',
      genderMale: yaml['gender_male']?.toString() ?? '男性',
      genderFemale: yaml['gender_female']?.toString() ?? '女性',
      genderOther: yaml['gender_other']?.toString() ?? '其他',
      saveProfile: yaml['save_profile']?.toString() ?? '保存画像',
      exportChat: yaml['export_chat']?.toString() ?? '导出聊天记录',
      factoryReset: yaml['factory_reset']?.toString() ?? '恢复出厂设置',
      apiKeyHint: yaml['api_key_hint']?.toString() ?? '请输入 API Key',
      nicknameHint: yaml['nickname_hint']?.toString() ?? '您的昵称',
    );
  }
}

class SuccessDialogStrings {
  final String profileSaved;
  final String configSaved;
  final String resetComplete;
  final String exportComplete;

  const SuccessDialogStrings({
    this.profileSaved = '用户画像已保存',
    this.configSaved = '配置已保存',
    this.resetComplete = '已恢复出厂设置',
    this.exportComplete = '导出成功',
  });

  factory SuccessDialogStrings.fromYaml(Map<String, dynamic> yaml) {
    return SuccessDialogStrings(
      profileSaved: yaml['profile_saved']?.toString() ?? '用户画像已保存',
      configSaved: yaml['config_saved']?.toString() ?? '配置已保存',
      resetComplete: yaml['reset_complete']?.toString() ?? '已恢复出厂设置',
      exportComplete: yaml['export_complete']?.toString() ?? '导出成功',
    );
  }
}

class MainScreenStrings {
  final String inputPlaceholder;

  const MainScreenStrings({
    this.inputPlaceholder = '说点什么...',
  });

  factory MainScreenStrings.fromYaml(Map<String, dynamic> yaml) {
    return MainScreenStrings(
      inputPlaceholder: yaml['input_placeholder']?.toString() ?? '说点什么...',
    );
  }
}

class CommonStrings {
  final String confirm;
  final String cancel;
  final String loading;

  const CommonStrings({
    this.confirm = '确认',
    this.cancel = '取消',
    this.loading = '加载中...',
  });

  factory CommonStrings.fromYaml(Map<String, dynamic> yaml) {
    return CommonStrings(
      confirm: yaml['confirm']?.toString() ?? '确认',
      cancel: yaml['cancel']?.toString() ?? '取消',
      loading: yaml['loading']?.toString() ?? '加载中...',
    );
  }
}

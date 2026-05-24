class AppConstants {
  // Agora — reemplaza con tu App ID del portal de Agora
  static const String agoraAppId = '3a30bbdebdab44bb8ffbe110afe1b059';

  // Cloudinary
  static const String cloudinaryCloudName = 'dpjozkpnr';
  static const String cloudinaryUploadPreset = 'ml_default';
  static const String cloudinaryBaseUrl =
      'https://api.cloudinary.com/v1_1/dpjozkpnr/auto/upload';

  // Carpetas Cloudinary
  static const String folderAvatars = 'avatars';
  static const String folderChatMedia = 'chat_media';
  static const String folderStories = 'stories';
  static const String folderFiles = 'board_files';

  // Dominios institucionales válidos
  static const List<String> validEmailDomains = [
    'itcelaya.edu.mx',
    'teccelaya.edu.mx',
  ];

  // Carreras del TecNM Celaya
  static const List<String> careers = [
    'Ing. Industrial',
    'Ing. en Sistemas Computacionales',
    'Ing. Mecatrónica',
    'Ing. Electrónica',
    'Ing. Química',
    'Ing. Bioquímica',
    'Administración',
    'Ing. Eléctrica',
    'Ing. Civil',
    'Ing. en Gestión Empresarial',
  ];

  // Roles
  static const String roleStudent = 'student';
  static const String roleProfessor = 'professor';

  // Tipos de mensaje
  static const String msgText = 'text';
  static const String msgImage = 'image';
  static const String msgVideo = 'video';
  static const String msgGif = 'gif';
  static const String msgEmoji = 'emoji';
  static const String msgFile  = 'file';
}

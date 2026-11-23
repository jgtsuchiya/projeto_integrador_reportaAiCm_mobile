import 'dart:convert';
import 'dart:typed_data';

/// Imagens pequenas de verdade para os testes, geradas uma vez (um asfalto com um buraco) e
/// guardadas em base64. São bytes que o app e a API aceitam: o JPEG com a assinatura, o SOF com
/// as dimensões e o fim (`FF D9`).

/// Uma foto de 160 x 120 px, sem EXIF: o que o `ImageCompressor` devolve para a foto do reporte.
final Uint8List samplePhotoJpeg = base64Decode(_photo);

/// Uma miniatura de 40 x 30 px, sem EXIF.
final Uint8List sampleThumbnailJpeg = base64Decode(_thumbnail);

/// Uma foto de 32 x 24 px com o EXIF (a orientação, o fabricante e o modelo do aparelho), como a
/// câmera grava.
final Uint8List sampleJpegWithExif = base64Decode(_withExif);

/// Um PNG de 16 x 12 px: a API e o app recusam, porque não é JPEG.
final Uint8List samplePng = base64Decode(_png);

const _photo =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsj'
    'HBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgo'
    'KCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAB4AKADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAA'
    'AAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAk'
    'M2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKT'
    'lJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QA'
    'HwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdh'
    'cRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hp'
    'anN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk'
    '5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDjWTLlQSp6Z/HNCgEZOBtGw4/iFPUM4bjGOvOSPxph2xh1Xhz7'
    'cVQDweG4G0cAH8+KRiCMEDIG0EdfTFNDfLucHHTFSMwPzbMAfnQAzcynbnBXvnr/AJwPyoVSwx04x/n8/wBaPkPy'
    'uvGegqQkHcCT0yKAGhmUkBsgnOcd/X60m7dIcj5hyD3pAp2+oXg051AiGwY46+9AA5wx87lMYAPT2pspLLjBBI+Z'
    'vb3qQJlSHOT600ly235R247igBkcjFQQxwMKO1OjZFI2D5lPAx3/AKVJ9nlP3YZCW6DYeakW1uTuAt5Bk8/IRQBU'
    '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';

const _thumbnail =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAoHBwgHBgoICAgLCgoLDhgQDg0NDh0VFhEYIx8lJCIfIiEmKzcvJik0'
    'KSEiMEExNDk7Pj4+JS5ESUM8SDc9Pjv/2wBDAQoLCw4NDhwQEBw7KCIoOzs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7'
    'Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozv/wAARCAAeACgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAA'
    'AAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAk'
    'M2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKT'
    'lJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QA'
    'HwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdh'
    'cRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hp'
    'anN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk'
    '5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDGxEP+Wj/98f8A16MQ/wB9/wDvgf41H7VFcXMdrEZJDgdvU0wL'
    'GIgPvSH/AICP8aX9z6yfpWIfEMQfAhO313c1oWt5DdpujY5HVT1oAt/uOuJPzFFR/hRTAOtUNWspLuBfL5ZM/L61'
    'f70E0gOQNjcB9pifP+6a29IsJbfMsoK5GAp61qUd6LAFFLjiimB//9k=';

const _withExif =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/4QBaRXhpZgAATU0AKgAAAAgAAwEPAAIAAAALAAAAMgEQAAIAAAATAAAAPgES'
    'AAMAAAABAAYAAAAAAABGYWJyaWNhbnRlAABNb2RlbG8gZG8gYXBhcmVsaG8AAP/bAEMABgQFBgUEBgYFBgcHBggK'
    'EAoKCQkKFA4PDBAXFBgYFxQWFhodJR8aGyMcFhYgLCAjJicpKikZHy0wLSgwJSgpKP/bAEMBBwcHCggKEwoKEyga'
    'FhooKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKP/AABEIABgAIAMBIgAC'
    'EQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEF'
    'EiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFla'
    'Y2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX'
    '2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIE'
    'BAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3'
    'ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1'
    'tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/AMt5tBiunW1s75kz'
    'hXklUPt7ZwMZ4HTiozPo68GyuiN24fvh19elZEZJY7EwG5Hsa4jxFrN2t3JAjFEVscd8U3oB6aZtFc7vsV2CB1Ew'
    '/wAKEm0MbQtne47BZgOfY4Iz+B+leWaPrt5FcrvdpF6FWOeK76NlMSu/GeeOwoTuA5iQSrfM/UgetZN7o9pfyAzL'
    'tmPYHBoopgJYaFZ2hMqIZCDwW6DHetPahKoWAU9v89qKKAP/2Q==';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAMCAIAAADkharWAAABl0lEQVR4nF1Ry27UQBDsnrcNFsQ2kBNk84BPyyE5'
    '8L9BPBx2WWklx85GHs+4e4aDIULUqapUKnWp8fr6hohijFVVee+NMX3fa63Lsuz73hgjhMg5T9MkpWzbFne7Xdfd'
    'w1/knHPO/8pngoibzZladUoJICMiAK4hRBBCImLOOaX0XIG3t59PT99575nZWhtjmOd5nr211lrnXKG19t6HEIwx'
    'XXevmPnu7otSChGHYZimp/2vLdGCgNa59x821rqUMjMLIZxzKsZojCEiWham5Wf3fXwciQgAjDFLjOcXH1GIoiiF'
    'EFJKwczrcZOfttvu+HSMMTIzM8/zPIxD133TWhtjAKAoCjEMAxHlnFfrP6xzmXkNjOOotNbMTERSys3mkpblYXiI'
    'MQKAUqp6WdXNG6U0ESEiAKi6rkMIOWdrC6PNxeWn7sfXEAMiSqma9m1ZvkBEpdQ8zwCghBAAYK39M9S6s/MrJko5'
    'aW0QEBCdc+tzmqYRKSUiCiH0fX84HIqiYE6vT+qqelXXzePx2LYtIu73eyml9/43FpT41fsvkOIAAAAASUVORK5C'
    'YII=';

/// Um JPEG mínimo com as dimensões do quadro e exatamente [length] bytes, para os limites da API
/// (ex.: a foto de 2 MB em ponto). Tem o início, o quadro (SOF0), o início dos dados (SOS), zeros
/// no lugar dos dados comprimidos e o fim. Com [withExif], um segmento APP1 com um texto qualquer
/// entra antes do quadro, como o EXIF da câmera.
Uint8List syntheticJpeg({
  required int width,
  required int height,
  int length = 0,
  bool withExif = false,
}) {
  final header = <int>[
    0xff, 0xd8, // início da imagem
    if (withExif) ...[0xff, 0xe1, 0x00, 0x0a, ...'Exif\x00\x00GP'.codeUnits],
    0xff, 0xc0, 0x00, 0x11, 0x08, // quadro: tamanho 17, precisão 8
    height >> 8, height & 0xff, width >> 8, width & 0xff,
    0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, // 3 componentes
    0xff, 0xda, 0x00, 0x0c, 0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3f, 0x00, // SOS
  ];
  const end = [0xff, 0xd9];
  final size = length > header.length + end.length ? length : header.length + end.length + 1;

  return Uint8List(size)
    ..setRange(0, header.length, header)
    ..setRange(size - end.length, size, end);
}

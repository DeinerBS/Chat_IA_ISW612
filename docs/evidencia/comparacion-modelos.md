# Comparación de modelos

Fecha: 2026-11-15 19:09 · VM: 2 vCPU, ~4 GB RAM, sin GPU · temperatura 0.2

| Modelo | Tamaño en disco | RAM cargado | Carga en frío | Primera respuesta (prom.) | Tokens/s (prom.) | Respuesta completa (prom.) |
|---|---|---|---|---|---|---|
| llama3.2:1b | 1.23 GB | 1.42 GB | 1.0 s | 0.31 s | 21.1 | 6.2 s |
| qwen2.5:1.5b | 0.92 GB | 1.09 GB | 4.0 s | 0.33 s | 24.5 | 6.3 s |
| gemma3:1b | 0.75 GB | 0.82 GB | 0.8 s | 0.54 s | 28.2 | 2.8 s |

*Primera respuesta* = carga + lectura del prompt (sin streaming). Los promedios de tiempo excluyen la primera pregunta, que incluye cargar el modelo.

## Respuestas (para evaluar la calidad)

### P1. Explica en dos oraciones qué es un firewall.

- **llama3.2:1b:** Un firewall es un software o hardware diseñado para proteger redes y sistemas de información contra ataques informáticos y amenazas externas, permitiendo solo el tráfico legítimo y bloqueando cualquier solicitud no autorizada.
- **qwen2.5:1.5b:** Un firewall es un sistema de seguridad que se encuentra en la línea de frente de una red, controlando la entrada y salida de datos para protegerla de amenazas externas. Es como un muro digital que se encarga de filtrar el tráfico de la red, bloqueando o permitiendo el acceso a los datos según las políticas establecidas.
- **gemma3:1b:** Un firewall es un sistema de seguridad que actúa como una barrera entre tu red y el exterior, controlando el tráfico de datos que entra y sale para proteger tu información de accesos no autorizados o amenazas.  Esto se logra bloqueando o permitiendo el acceso a datos basándose en reglas predefinidas.

### P2. Redacta un correo breve para solicitar vacaciones del 20 al 24 de diciembre.

- **llama3.2:1b:** Asunto: Solicitación de vacaciones del 20 al 24 de diciembre<br>Estimado/a [Nombre del destinatario],<br>Me dirijo a usted para solicitar las vacaciones del 20 al 24 de diciembre. Me gustaría tomar un descanso de trabajo durante este período y aprovechar el tiempo para mi familia y mis intereses personales.<br>Agradecería si pudiera confirmar mi solicitud y proporcionarle información sobre las medidas de seguridad que se tomarán para garantizar mi asistencia en caso de emergencia.<br>Agradezco su tiempo y consideración.<br>Atentamente,<br>[Tu nombre]
- **qwen2.5:1.5b:** Asunto: Solicita permiso para vacaciones del 20 al 24 de diciembre<br>Querido [Nombre del jefe],<br>Espero que este mensaje le encuentre bien. Me dirijo a usted para solicitar permiso para ausentarme del trabajo del 20 al 24 de diciembre.<br>Estoy de vacaciones y me gustaría aprovechar esta oportunidad para descansar, relajarme y disfrutar de la familia. He estado trabajando muy duro estos últimos meses y necesito un tiempo para recuperarme y descansar.<br>Si es posible, me gustaría poder hacerlo en la fecha mencionada. Si hay alguna necesidad de reemplazo, estaría encantado de informarle de la disponibilidad de mi equipo para asumir mis tareas.<br>Gracias por su comprensión y permiso para esta solicitud. Espero poder contar con su aprobación y estar a su disposición para cualquier consulta o necesidad que pueda surgir durante mi ausencia.<br>Atentamente,<br>[Tu nombre]
- **gemma3:1b:** Asunto: Solicitud de Vacaciones - [Tu Nombre]<br>Estimado/a [Nombre del Supervisor],<br>Le escribo para solicitar unas vacaciones del 20 al 24 de diciembre.<br>Agradezco su consideración.<br>Atentamente,<br>[Tu Nombre]

### P3. Un producto cuesta 12 500 colones y se le suma 13 % de IVA. ¿Cuál es el precio final? Muestra el cálculo.

- **llama3.2:1b:** Para calcular el precio final del producto, podemos utilizar la fórmula:<br>Precio final = Precio original + (Precio original x % de IVA)<br>En este caso, el precio original es de 12 500 colones y el porcentaje de IVA es del 13%.<br>Primero, calculamos el porcentaje de IVA:<br>13% = 0,13<br>Luego, multiplicamos el precio original por el porcentaje de IVA:<br>Precio original x % de IVA = 12 500 x 0,13<br>= 1 625<br>Ahora, sumamos el precio original y el porcentaje de IVA para obtener el precio final:<br>Precio final = Precio original + (Precio original x % de IVA)<br>= 12 500 + 1 625<br>= 14 125<br>Por lo tanto, el precio final del producto es de 14 125 colones.
- **qwen2.5:1.5b:** Para calcular el precio final de un producto con IVA incluido, primero debemos calcular el valor del IVA y luego sumarlo al precio original.<br>1. **Calcular el valor del IVA:**<br>   - El precio original es de 12,500 colones.<br>   - El IVA es de 13%.<br>   - El valor del IVA es: \( 12,500 \times 0.13 = 1,625 \) colones.<br>2. **Calcular el precio final:**<br>   - El precio final es el precio original más el valor del IVA.<br>   - El precio final es: \( 12,500 + 1,625 = 14,125 \) colones.<br>Por lo tanto, el precio final del producto es de 14,125 colones.
- **gemma3:1b:** ¡Hola!<br>El precio final será de 12.500 colones + (13% de 12.500 colones) = 12.500 + 1.575 colones = 14.075 colones.<br>El precio final es de **14.075 colones**.

### P4. Resume en tres puntos las ventajas de usar contraseñas largas.

- **llama3.2:1b:** Aquí te presento las ventajas de usar contraseñas largas:<br>1.  **Mayor seguridad**: Las contraseñas largas son más difíciles de adivinar para los hackers, lo que reduce el riesgo de ataques de seguridad.<br>2.  **Mejora de la autenticación**: Las contraseñas largas pueden ser más difíciles de obtener para los usuarios, lo que mejora la autenticación y la seguridad de la red.<br>3.  **Mayor confianza**: Las contraseñas largas pueden aumentar la confianza de los usuarios en la seguridad de la red, ya que se consideran más seguras y respetables.
- **qwen2.5:1.5b:** 1. Incrementa la seguridad: Las contraseñas más largas son más difíciles de crackear, lo que aumenta la protección contra ataques de fuerza bruta.<br>2. Evita ataques de fuerza bruta: Las contraseñas más largas dificultan los intentos de fuerza bruta, lo que reduce la probabilidad de que se logre acceder al sistema.<br>3. Facilita la identificación: Las contraseñas más largas son más difíciles de recordar, lo que facilita la identificación y la autenticación, lo que es especialmente útil en entornos de trabajo remoto.
- **gemma3:1b:** ¡Claro! Aquí tienes tres puntos que resumen las ventajas de usar contraseñas largas:<br>1.  **Mayor seguridad:** Las contraseñas largas son más difíciles de adivinar para los hackers.<br>2.  **Protección de datos:** Reducen el riesgo de que tus cuentas se vean comprometidas.<br>3.  **Mayor privacidad:**  Te protegen de posibles accesos no autorizados a tus cuentas.

### P5. ¿Cuál es la capital de Costa Rica y en qué provincia está?

- **llama3.2:1b:** La capital de Costa Rica es San José. Está ubicada en la provincia de San José.
- **qwen2.5:1.5b:** La capital de Costa Rica es San José. Está ubicada en la provincia de San José.
- **gemma3:1b:** La capital de Costa Rica es San José. Está ubicada en la provincia de Alajuela.


# VIRTUALCORP
## Despliegue y configuración de la infraestructura informática

**Proyecto:** VirtualCorp  
**Sistema de virtualización:** Oracle VirtualBox 7.2.6  
**Sistema operativo de los servidores:** Debian GNU/Linux  
**Plataforma de virtualización adicional:** Proxmox VE  
**Sistema de routers:** MikroTik RouterOS  

---

# 1. Introducción

En este proyecto se ha desarrollado y preparado una infraestructura informática virtualizada para VirtualCorp.

El objetivo principal ha sido automatizar la creación y el despliegue de diferentes equipos informáticos, configurar sus redes internas y preparar una infraestructura que permita la comunicación entre servidores, ordenadores, impresoras y routers.

Para realizar el proyecto se ha utilizado VirtualBox como plataforma principal de virtualización. También se ha instalado Proxmox VE en una máquina virtual independiente para disponer de una plataforma adicional de virtualización.

Se han utilizado scripts de Bash para automatizar diferentes tareas y evitar tener que configurar manualmente cada máquina virtual.

La infraestructura está dividida en diferentes redes para separar los equipos según su función.

# 2. Herramientas utilizadas

## 2.1. Oracle VirtualBox

VirtualBox es el programa utilizado para crear y administrar las máquinas virtuales.

Permite ejecutar diferentes sistemas operativos dentro de un mismo ordenador físico sin necesidad de instalar cada sistema directamente en el hardware.

En este proyecto se utiliza para crear:

- Servidores Debian.
- Ordenadores de escritorio Debian.
- Impresoras virtualizadas.
- Routers MikroTik.
- Un servidor Proxmox VE.

La administración se realiza principalmente mediante comandos utilizando `VBoxManage`.

## 2.2. Debian GNU/Linux

Debian es el sistema operativo utilizado para las máquinas que desempeñan las funciones de servidores, escritorios e impresoras.

Se han preparado dos plantillas diferentes:

- Debian Server Template.
- Debian Desktop Template.

La plantilla de servidor está orientada a servicios y administración mediante terminal.

La plantilla de escritorio incorpora un entorno gráfico para que los usuarios puedan trabajar de manera visual.

## 2.3. MikroTik RouterOS

MikroTik RouterOS es el sistema utilizado para configurar los routers de la infraestructura.

Estos routers permiten comunicar diferentes redes internas, gestionar el encaminamiento y proporcionar salida a Internet cuando corresponde.

## 2.4. Proxmox VE

Proxmox VE es una plataforma de virtualización que permite administrar máquinas virtuales y contenedores desde una interfaz web.

Se ha instalado en una máquina virtual independiente llamada `pve01`.

# 3. Arquitectura de red

La infraestructura está organizada mediante diferentes redes internas.

Esta separación permite distribuir los equipos según su función y controlar cómo se comunican entre ellos.

Las redes utilizadas son:

| Red | Dirección de red | Función |
|---|---|---|
| privada | 10.10.0.128/26 | Servidores internos y Proxmox |
| dmz | 10.10.0.192/27 | Servidor web |
| pl0 | 10.10.0.0/25 | Ordenadores y equipos de la primera planta |
| pl1 | 10.10.1.0/24 | Equipos de la segunda red |
| pl2 | 10.10.2.0/24 | Equipos de la tercera red |
| pl3 | 10.10.3.0/25 | Equipos de la cuarta red |
| pl3_direccio | 10.10.3.128/25 | Red de dirección |
| rt0_1 | 10.10.0.224/30 | Enlace entre routers |
| rt1_2 | 10.10.0.228/30 | Enlace entre routers |
| rt2_3 | 10.10.0.232/30 | Enlace entre routers |

## 3.1. Red privada

La red privada se utiliza para alojar los servidores internos de VirtualCorp.

En ella se encuentran:

- `dbsrv`: servidor de bases de datos.
- `infosrv`: servidor de información.
- `pve01`: servidor Proxmox VE.

Esta red utiliza el direccionamiento 10.10.0.128/26.

La puerta de enlace configurada es 10.10.0.129.

## 3.2. Red DMZ

La DMZ es una zona de red separada que permite alojar servicios que pueden necesitar comunicación con otras redes.

En este proyecto se utiliza para alojar:

- `websrv`: servidor web.

La red DMZ utiliza 10.10.0.192/27 y tiene como puerta de enlace 10.10.0.193.

Separar el servidor web de los servidores internos mejora la organización y permite establecer políticas de seguridad específicas.

## 3.3. Redes de usuarios

Las redes `pl0`, `pl1`, `pl2` y `pl3` permiten separar los equipos de diferentes zonas de la organización.

En ellas se distribuyen los ordenadores y las impresoras.

Cada red dispone de su propio direccionamiento IP y su correspondiente puerta de enlace.

## 3.4. Enlaces entre routers

Las redes `rt0_1`, `rt1_2` y `rt2_3` se utilizan para conectar los routers entre sí.

Se han utilizado subredes /30 porque permiten disponer de dos direcciones utilizables, suficientes para conectar dos extremos de un enlace.

# 4. Máquinas virtuales desplegadas

La infraestructura incluye diferentes equipos con funciones específicas.

| Máquina | Función | Red |
|---|---|---|
| dbsrv | Servidor de bases de datos | privada |
| infosrv | Servidor de información | privada |
| websrv | Servidor web | dmz |
| expo1 | Ordenador de usuario | pl0 |
| expo2 | Ordenador de usuario | pl0 |
| expo3 | Ordenador de usuario | pl0 |
| expo4 | Ordenador de usuario | pl0 |
| printer0 | Impresora virtualizada | pl0 |
| printer1 | Impresora virtualizada | pl1 |
| printer2 | Impresora virtualizada | pl2 |
| printer3 | Impresora virtualizada | pl3 |
| pve01 | Plataforma Proxmox VE | privada |

Los routers MikroTik se encargan de interconectar las diferentes redes.

# 5. Creación automatizada de plantillas Debian

Para evitar instalar Debian manualmente en cada máquina, se ha creado un sistema de plantillas.

Las plantillas permiten preparar una máquina una sola vez y utilizarla como base para crear otros equipos.

Se han creado dos tipos:

## 5.1. Debian Server Template

Esta plantilla está destinada a los servidores y a las impresoras virtualizadas.

Incluye:

- Sistema Debian.
- Usuario de administración `sysadmin`.
- Acceso mediante SSH.
- Herramientas de administración.
- Paquetes necesarios para trabajar desde terminal.
- Configuración de permisos de administración mediante sudo.

## 5.2. Debian Desktop Template

Esta plantilla está destinada a los ordenadores de los usuarios.

Además de los componentes básicos de Debian, incorpora:

- Entorno gráfico LXQt.
- Gestor de inicio de sesión LightDM.
- Navegador Falkon.
- Herramientas de red.
- Git.
- SSH.
- Utilidades de administración.

De esta manera, los ordenadores disponen de un entorno gráfico preparado para trabajar.

# 6. Instalación desatendida mediante Preseed

Para automatizar la instalación de Debian se utiliza el sistema Preseed.

Preseed permite proporcionar respuestas anticipadas al instalador de Debian.

Gracias a este sistema, no es necesario responder manualmente a todas las preguntas durante la instalación.

Los archivos utilizados son:

- `infrastructure/preseed/server.cfg`
- `infrastructure/preseed/desktop.cfg`

Estos archivos contienen parámetros como:

- Idioma del sistema.
- Distribución del teclado.
- Nombre del equipo.
- Usuario administrador.
- Configuración horaria.
- Paquetes que deben instalarse.
- Particionado automático del disco.
- Configuración del cargador de arranque.

También se prepara el acceso SSH mediante claves públicas autorizadas.

Una vez terminada la instalación, las máquinas se apagan automáticamente para poder utilizarlas como plantillas.

# 7. Automatización mediante scripts Bash

Una parte importante del proyecto consiste en automatizar las operaciones mediante scripts.

Esto permite reducir errores y repetir las operaciones de manera sencilla.

## 7.1. Script create_templates.sh

Este script se encarga de crear las plantillas Debian.

Sus principales funciones son:

1. Comprobar que VirtualBox está disponible.
2. Descargar la ISO de Debian cuando no existe.
3. Preparar las claves públicas SSH.
4. Generar los archivos Preseed.
5. Crear las máquinas virtuales.
6. Asignar memoria RAM y procesadores.
7. Crear los discos virtuales.
8. Ejecutar la instalación desatendida.
9. Esperar a que termine la instalación.
10. Configurar la red de las plantillas.
11. Crear un snapshot base.

El objetivo es disponer de plantillas preparadas para crear equipos sin repetir todo el proceso de instalación.

## 7.2. Script deploy_equipment.sh

Este script se encarga de desplegar los equipos definidos en el archivo de configuración.

Para cada equipo realiza las siguientes operaciones:

1. Comprueba que las plantillas existen.
2. Comprueba que están apagadas.
3. Comprueba si el equipo ya existe.
4. Obtiene el snapshot base correspondiente.
5. Crea un clon enlazado de la plantilla.
6. Asigna el nombre de la máquina.
7. Conecta la máquina a la red interna correspondiente.

Se utilizan clones enlazados para ahorrar espacio en disco.

Un clon enlazado utiliza el disco de la plantilla como base y almacena los cambios propios de la máquina en un disco diferencial.

Esto permite desplegar varios equipos sin duplicar completamente el contenido de cada disco.

Al finalizar, el script ejecuta el despliegue de Proxmox mediante `deploy_pve01.sh`.

## 7.3. Archivo equipment.conf

Este archivo contiene la lista de equipos que deben desplegarse.

Cada línea utiliza tres campos:

- Nombre de la máquina.
- Plantilla que debe utilizar.
- Red interna a la que debe conectarse.

Por ejemplo:

`dbsrv|Debian-Server-Template|privada`

Esto indica que se debe crear una máquina llamada `dbsrv`, utilizando la plantilla de servidor y conectándola a la red privada.

De esta forma, se puede modificar el inventario de equipos sin tener que cambiar el funcionamiento principal del script.

# 8. Configuración DHCP

Se ha preparado la configuración de las plantillas Debian para utilizar DHCP.

DHCP es un protocolo que permite asignar automáticamente los parámetros de red a los equipos.

Entre estos parámetros se encuentran:

- Dirección IP.
- Máscara de red.
- Puerta de enlace.
- Servidores DNS.

El objetivo es que los equipos no necesiten una configuración IP manual.

Cada máquina debe recibir una dirección correspondiente a su red.

Las direcciones previstas para los servidores son:

| Máquina | Dirección prevista |
|---|---|
| dbsrv | 10.10.0.134 |
| infosrv | 10.10.0.135 |
| websrv | 10.10.0.197 |

También se han definido direcciones previstas para los ordenadores y las impresoras.

Es importante distinguir entre preparar los clientes para DHCP y desplegar los servidores DHCP: para que los equipos reciban direcciones automáticamente, los routers o servidores correspondientes deben tener los servicios DHCP configurados y activos.

# 9. Configuración de Proxmox VE

Se ha instalado Proxmox VE en una máquina virtual independiente llamada `pve01`.

A diferencia de las máquinas Debian, Proxmox no utiliza la configuración DHCP prevista para los demás equipos.

Se le ha asignado una dirección estática:

| Parámetro | Valor |
|---|---|
| Nombre | pve01 |
| Dirección IP | 10.10.0.133 |
| Máscara | /26 |
| Puerta de enlace | 10.10.0.129 |
| Puerto web | 8006 |

La instalación se ha preparado mediante el script:

`scripts/deploy_pve01.sh`

Este script automatiza la preparación de la ISO de Proxmox, la creación de la máquina virtual y el inicio del instalador.

También se ha habilitado la virtualización anidada.

La virtualización anidada permite que una máquina virtual utilice capacidades de virtualización por hardware para ejecutar otras máquinas virtuales.

Se ha comprobado que el sistema identifica la virtualización mediante KVM.

También se ha comprobado que el servicio web de Proxmox responde a través de HTTPS en el puerto 8006 desde la red interna.

# 10. Configuración de los routers

Los routers MikroTik permiten conectar las diferentes redes de la infraestructura.

Se han preparado cuatro routers:

- mikrotik0
- mikrotik1
- mikrotik2
- mikrotik3

Sus funciones incluyen:

- Configurar las interfaces de red.
- Asignar direcciones IP.
- Establecer rutas entre redes.
- Permitir la comunicación entre diferentes segmentos.
- Gestionar la salida a Internet.

El router `mikrotik0` es el único que debe disponer de conexión NAT hacia el exterior, según los requisitos del proyecto.

Los enlaces entre routers utilizan las redes específicas definidas en el diseño de direccionamiento.

# 11. Pruebas de funcionamiento

Para comprobar el funcionamiento de la infraestructura se utilizan diferentes pruebas.

## 11.1. Comprobar las máquinas encendidas

Desde Ubuntu se utiliza:

```bash
VBoxManage list runningvms
```

Este comando muestra las máquinas virtuales que están ejecutándose.

## 11.2. Comprobar las redes internas

Se puede utilizar:

```bash
VBoxManage showvminfo dbsrv --machinereadable
```

Permite consultar la configuración de la máquina y verificar a qué red interna está conectada.

## 11.3. Comprobar las direcciones IP

Dentro de Debian:

```bash
ip -br addr
```

Este comando muestra las interfaces de red y las direcciones IP asignadas.

## 11.4. Comprobar las rutas

Dentro de Debian:

```bash
ip route
```

Permite comprobar la puerta de enlace y las rutas disponibles.

## 11.5. Comprobar conectividad mediante ping

Para comprobar que dos equipos pueden comunicarse se utiliza:

```bash
ping -c 4 DIRECCION_IP
```

Por ejemplo:

```bash
ping -c 4 10.10.0.129
```

Si se reciben respuestas, significa que existe comunicación IP entre ambos equipos.

## 11.6. Comprobar Proxmox

Se ha utilizado el siguiente comando desde MikroTik:

```routeros
/tool fetch url="https://10.10.0.133:8006" check-certificate=no output=none
```

La respuesta `status: finished` permitió comprobar que el servicio HTTPS de Proxmox respondía desde la red interna en el momento de la prueba.

# 12. Seguridad y administración

Se han preparado diferentes mecanismos para facilitar la administración de los equipos.

Entre ellos destacan:

- Acceso SSH.
- Autenticación mediante claves públicas.
- Usuario administrativo `sysadmin`.
- Permisos sudo.
- Separación de redes.
- Uso de una DMZ para el servidor web.
- Configuración independiente de Proxmox.

La separación de redes permite organizar mejor los equipos y facilita la aplicación de reglas de seguridad.

También es importante proteger las contraseñas y evitar incluir credenciales en repositorios públicos.

# 13. Organización del proyecto

La estructura del proyecto se organiza en diferentes directorios:

| Directorio | Función |
|---|---|
| `configs/` | Archivos de configuración |
| `configs/templates/` | Configuración de las plantillas |
| `configs/ssh/` | Claves públicas SSH |
| `infrastructure/preseed/` | Archivos de instalación desatendida |
| `scripts/` | Scripts de automatización |
| `iso/` | Imágenes ISO utilizadas |
| `build/` | Archivos generados durante la preparación |
| `docs/` | Documentación del proyecto |

Esta organización facilita el mantenimiento y permite localizar rápidamente cada elemento.

# 14. Conclusión

Durante este proyecto se ha preparado una infraestructura virtualizada para VirtualCorp utilizando VirtualBox, Debian, MikroTik y Proxmox VE.

Se han creado mecanismos de instalación desatendida para Debian y scripts de automatización para generar plantillas y desplegar diferentes equipos.

También se ha diseñado una arquitectura de red dividida en diferentes segmentos, con redes privadas, una DMZ, redes de usuarios y enlaces entre routers.

La instalación de Proxmox VE añade una plataforma de virtualización adicional y permite trabajar con virtualización anidada.

El uso de plantillas, clones enlazados y scripts permite reducir el trabajo manual, facilitar la repetición de los despliegues y mantener una infraestructura organizada.

Como resultado, se dispone de una base automatizada para desplegar y administrar los equipos de VirtualCorp.

**Estado final:** la infraestructura debe considerarse terminada cuando se hayan comprobado las direcciones DHCP, las comunicaciones entre redes, el funcionamiento de los routers, los servicios de los servidores y la automatización completa del despliegue.

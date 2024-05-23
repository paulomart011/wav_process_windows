using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Threading;
using System.Timers;
using System.ServiceProcess;
using System.Linq;
using Renci.SshNet;
using Renci.SshNet.Sftp;
using System.Configuration;
using System.Net.Mail;
using System.Net;
using System.Web.Script.Serialization;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Diagnostics;
using Microsoft.Win32.SafeHandles;
using System.Runtime.ConstrainedExecution;
using System.Security;
using System.Security.Principal;
using System.Security.Permissions;
using System.Threading.Tasks;
using Amazon.S3;
using Amazon.S3.Model;

namespace inConcertSpeechRespaldoSFTP
{
   

    public partial class Service1 : ServiceBase
    {

        public const string APP_NAME = "inConcertSpeechRespaldoSFTP";
        private static System.Timers.Timer timer;

        //private static string LOG_PATH = "C:\\Windows\\SysWOW64\\config\\systemprofile\\inConcert\\Logs\\";
        private static string LOG_PATH = ConfigurationManager.AppSettings["Log_Folder"];

        public Service1()
        {
            InitializeComponent();
            ServiceName = "inConcertSpeechRespaldoSFTP";
        }

        protected override void OnStart(string[] args)
        {

            try
            {
                timer = new System.Timers.Timer();
                timer.Elapsed += new ElapsedEventHandler(OnTimedEventGenerarReporte);
                timer.Interval = 10000;
                timer.Enabled = true;
            }
            catch (Exception ex)
            {
                logError("Error al iniciar - " + ex.Message + " - " + ex.StackTrace);
            }
        }

        protected override void OnStop()
        {
            timer.Enabled = false;
        }

        private void OnTimedEventGenerarReporte(object source, ElapsedEventArgs e)
        {

            //--logDebug("OnTimedEventGenerarReporte");

            timer.Stop();
            GC.Collect();

            try
            {
                DateTime tmstmp = DateTime.UtcNow;
                procesar(tmstmp);
            }
            catch (Exception ex)
            {
                logError("Error al procesar - " + ex.Message + " - " + ex.StackTrace);
            }
            int tiempo_minutos = Int32.Parse(ConfigurationManager.AppSettings["tiempo_minutos"]);
            timer.Interval = tiempo_minutos * 60 * 1000;
            timer.Start();

        }

        private void procesar(DateTime tmstmp)
        {

            try
            {
                string temp_folder = ConfigurationManager.AppSettings["Temp_Folder"];
                string[] folders = System.IO.Directory.GetDirectories(temp_folder, "*", System.IO.SearchOption.AllDirectories);
                logDebug("LOG: " + folders);
                ProcesarArchivosYFoldersAsync(folders);
            }
            catch (Exception ex)
            {
                logError("Error al Procesar - " + ex.Message + " - " + ex.StackTrace);
            }
            
        }

        public void ProcesarArchivosYFoldersAsync(string[] sftp_folders_create)
        {
            string temp_directory = ConfigurationManager.AppSettings["Temp_Directory"];
            int cantidad_archivos = Int32.Parse(ConfigurationManager.AppSettings["cantidad_archivos"]);
            int cantidad_nodos = Int32.Parse(ConfigurationManager.AppSettings["cantidad_nodos"]);
            string accessKey = ConfigurationManager.AppSettings["accessKey"];
            string secretKey = ConfigurationManager.AppSettings["secretKey"];
            string bucketName = ConfigurationManager.AppSettings["bucketName"];

            var credentials = new Amazon.Runtime.BasicAWSCredentials(accessKey, secretKey);

            // DEFINIR LA REGION
            var s3Client = new AmazonS3Client(credentials, Amazon.RegionEndpoint.USEast1);

            try
            {
               
                if(sftp_folders_create.Length > 0) {
                    logDebug("LOG :" + sftp_folders_create.Length);

                        foreach (string folder in sftp_folders_create)
                        {
                            bool delete_folder = false;

                        try
                        {
                            logDebug("SubirArchivosDeFolderFTP - " + folder + ", " + folder.Replace("\\", "/").Replace(temp_directory, ""));

                            string[] Archivos = Directory.EnumerateFiles(folder)
                            .Where(f => !Path.GetFileName(f).StartsWith("PROCESS_"))
                            .Take(cantidad_archivos)
                            .ToArray();

                            string[] subfolders = System.IO.Directory.GetDirectories(folder, "*", System.IO.SearchOption.AllDirectories);

                            logDebug("Folder: " + folder + ", Archivos: " + Archivos.Length + ", Subfolders: " + subfolders.Length);


                            string[] sub_folders = folder.Replace("\\", "/").Replace(temp_directory, "").Split('/');

                            if (Archivos.Length == 0 && subfolders.Length == 0)
                            {
                                delete_folder = true; // Quiero eliminar las que tengan vacios

                                if (sub_folders.Length == 5) // Valido para las rutas completas (anio/mes/dia) si la fecha es antes de hoy, de ser asi y no tiene archivos elimino la carpeta
                                {
                                    DateTime fecha_carpeta = new DateTime(Int32.Parse(sub_folders[2]), Int32.Parse(sub_folders[3]), Int32.Parse(sub_folders[4]));
                                    DateTime fecha_actual = DateTime.UtcNow;
                                    if (DateTime.Compare(fecha_carpeta, fecha_actual.AddDays(-1)) < 0)
                                    {
                                        delete_folder = true;
                                    }
                                    else
                                    {
                                        delete_folder = false;
                                    }
                                }

                                if (delete_folder)
                                {
                                    logDebug("DeleteLocalFolder - Folder: " + delete_folder);
                                    System.IO.Directory.Delete(folder);
                                }
                            }


                            if (Archivos.Length > 0 && subfolders.Length == 0)
                            {

                                ParallelOptions opciones = new ParallelOptions();
                                opciones.MaxDegreeOfParallelism = cantidad_nodos;

                                Parallel.ForEach(Archivos, opciones, async Archivo =>
                                {
                                    bool procesado = false;

                                    string ArchivoFinal = Archivo.Replace(temp_directory, "");

                                    FileInfo fileinfo = new FileInfo(Archivo);

                                    string originalNameWithoutExtension = Path.GetFileNameWithoutExtension(fileinfo.FullName);
                                    string newFileName = "PROCESS_" + originalNameWithoutExtension + fileinfo.Extension;
                                    string newFilepath = Path.Combine(fileinfo.DirectoryName, newFileName);

                                    try
                                    {

                                        await Task.Run(() => fileinfo.MoveTo(newFilepath));
                                    }
                                    catch (Exception ex)
                                    {
                                        logError($"Error al renombrar el archivo {Archivo}: {ex.Message}");
                                    }

                                    try
                                    {

                                        using (var fileStream = File.OpenRead(newFilepath))
                                        {
                                            var request = new PutObjectRequest
                                            {
                                                BucketName = bucketName,
                                                Key = ArchivoFinal.Remove(0, 1).Replace("\\", "/"),
                                                InputStream = fileStream
                                            };
                                            await s3Client.PutObjectAsync(request);
                                        }
                                        procesado = true;
                                        logDebug($"El archivo {Archivo} ha sido transferido a {ArchivoFinal.Remove(0, 1).Replace("\\", "/")}");
                                    }
                                    catch (Exception ex)
                                    {
                                        logError($"Error al transferir el archivo {Archivo}: {ex.Message}");
                                    }

                                    if (procesado)
                                    {
                                        try
                                        {
                                            System.IO.File.Delete(newFilepath);
                                        }
                                        catch (Exception ex5)
                                        {
                                            logError("Error al eliminar el archivo: " + newFilepath + ", " + ex5.Message + " - " + ex5.StackTrace);
                                        }
                                    }


                                });

                            }
                        }
                        catch (Exception ex2)
                        {
                            logError("Error al procesar archivos de: " + folder + ", " + ex2.Message + " - " + ex2.StackTrace);
                        }
                        }

                }

            }
            catch (Exception ex1)
            {
                logError("Error en ProcesarArchivosYFolders: " + ex1.Message + " - " + ex1.StackTrace);
            }
        }

        public static bool IsFileInUse(string filePath)
        {
            try
            {
                using (FileStream fs = new FileStream(filePath, FileMode.Open, FileAccess.ReadWrite, FileShare.None))
                {
                    // Si el archivo puede ser abierto sin excepciones, entonces no está en uso
                    return false;
                }
            }
            catch (IOException)
            {
                // Si se lanza una excepción IOException, el archivo está en uso
                return true;
            }
        }

        public static string ConnectToShare(string uri, string username, string password)
        {
            try
            {
                //Create netresource and point it at the share
                NETRESOURCE nr = new NETRESOURCE();
                nr.dwType = RESOURCETYPE_DISK;
                nr.lpRemoteName = uri;

                //Create the share
                int ret = WNetUseConnection(IntPtr.Zero, nr, password, username, 0, null, null, null);

                //Check for errors
                if (ret == NO_ERROR)
                    return null;
                else
                    return GetError(ret);
            }
            catch (Exception ex)
            {
                throw ex;
            }
            
        }

        public static string DisconnectFromShare(string uri, bool force)
        {
            try
            {
                //remove the share
                int ret = WNetCancelConnection(uri, force);

                //Check for errors
                if (ret == NO_ERROR)
                    return null;
                else
                    return GetError(ret);
            }
            catch (Exception ex)
            {
                throw ex;
            }
            
        }

        private void logError(String text)
        {
            try
            {
                LoggingExtensions.WriteDebug(LOG_PATH, APP_NAME, "[ERROR]	" + DateTime.Now.ToString("yyyyMMdd_HH:mm:ss") + "	" + text);

                if (!System.Diagnostics.EventLog.SourceExists(APP_NAME))
                    System.Diagnostics.EventLog.CreateEventSource(APP_NAME, "Application");

                System.Diagnostics.EventLog.WriteEntry(APP_NAME, text, System.Diagnostics.EventLogEntryType.Error);
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Console.WriteLine(ex.StackTrace);
            }
        }

        private void logDebug(String text)
        {
            try
            {
                LoggingExtensions.WriteDebug(LOG_PATH, APP_NAME, "[DEBUG]	" + DateTime.Now.ToString("yyyyMMdd_HH:mm:ss") + "	" + text);
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Console.WriteLine(ex.StackTrace);
            }
        }
        
        #region P/Invoke Stuff
        [DllImport("Mpr.dll")]
        private static extern int WNetUseConnection(
            IntPtr hwndOwner,
            NETRESOURCE lpNetResource,
            string lpPassword,
            string lpUserID,
            int dwFlags,
            string lpAccessName,
            string lpBufferSize,
            string lpResult
            );

        [DllImport("Mpr.dll")]
        private static extern int WNetCancelConnection(
            string lpName,
            bool fForce
            );

        [StructLayout(LayoutKind.Sequential)]
        private class NETRESOURCE
        {
            public int dwScope = 0;
            public int dwType = 0;
            public int dwDisplayType = 0;
            public int dwUsage = 0;
            public string lpLocalName = "";
            public string lpRemoteName = "";
            public string lpComment = "";
            public string lpProvider = "";
        }

        #region Consts
        const int RESOURCETYPE_DISK = 0x00000001;
        const int CONNECT_UPDATE_PROFILE = 0x00000001;
        #endregion

        #region Errors
        const int NO_ERROR = 0;

        const int ERROR_ACCESS_DENIED = 5;
        const int ERROR_ALREADY_ASSIGNED = 85;
        const int ERROR_BAD_DEVICE = 1200;
        const int ERROR_BAD_NET_NAME = 67;
        const int ERROR_BAD_PROVIDER = 1204;
        const int ERROR_CANCELLED = 1223;
        const int ERROR_EXTENDED_ERROR = 1208;
        const int ERROR_INVALID_ADDRESS = 487;
        const int ERROR_INVALID_PARAMETER = 87;
        const int ERROR_INVALID_PASSWORD = 1216;
        const int ERROR_MORE_DATA = 234;
        const int ERROR_NO_MORE_ITEMS = 259;
        const int ERROR_NO_NET_OR_BAD_PATH = 1203;
        const int ERROR_NO_NETWORK = 1222;
        const int ERROR_SESSION_CREDENTIAL_CONFLICT = 1219;

        const int ERROR_BAD_PROFILE = 1206;
        const int ERROR_CANNOT_OPEN_PROFILE = 1205;
        const int ERROR_DEVICE_IN_USE = 2404;
        const int ERROR_NOT_CONNECTED = 2250;
        const int ERROR_OPEN_FILES = 2401;

        private struct ErrorClass
        {
            public int num;
            public string message;
            public ErrorClass(int num, string message)
            {
                this.num = num;
                this.message = message;
            }
        }

        private static ErrorClass[] ERROR_LIST = new ErrorClass[] {
        new ErrorClass(ERROR_ACCESS_DENIED, "Error: Access Denied"),
        new ErrorClass(ERROR_ALREADY_ASSIGNED, "Error: Already Assigned"),
        new ErrorClass(ERROR_BAD_DEVICE, "Error: Bad Device"),
        new ErrorClass(ERROR_BAD_NET_NAME, "Error: Bad Net Name"),
        new ErrorClass(ERROR_BAD_PROVIDER, "Error: Bad Provider"),
        new ErrorClass(ERROR_CANCELLED, "Error: Cancelled"),
        new ErrorClass(ERROR_EXTENDED_ERROR, "Error: Extended Error"),
        new ErrorClass(ERROR_INVALID_ADDRESS, "Error: Invalid Address"),
        new ErrorClass(ERROR_INVALID_PARAMETER, "Error: Invalid Parameter"),
        new ErrorClass(ERROR_INVALID_PASSWORD, "Error: Invalid Password"),
        new ErrorClass(ERROR_MORE_DATA, "Error: More Data"),
        new ErrorClass(ERROR_NO_MORE_ITEMS, "Error: No More Items"),
        new ErrorClass(ERROR_NO_NET_OR_BAD_PATH, "Error: No Net Or Bad Path"),
        new ErrorClass(ERROR_NO_NETWORK, "Error: No Network"),
        new ErrorClass(ERROR_BAD_PROFILE, "Error: Bad Profile"),
        new ErrorClass(ERROR_CANNOT_OPEN_PROFILE, "Error: Cannot Open Profile"),
        new ErrorClass(ERROR_DEVICE_IN_USE, "Error: Device In Use"),
        new ErrorClass(ERROR_EXTENDED_ERROR, "Error: Extended Error"),
        new ErrorClass(ERROR_NOT_CONNECTED, "Error: Not Connected"),
        new ErrorClass(ERROR_OPEN_FILES, "Error: Open Files"),
        new ErrorClass(ERROR_SESSION_CREDENTIAL_CONFLICT, "Error: Credential Conflict"),
    };

        private static string GetError(int errNum)
        {
            foreach (ErrorClass er in ERROR_LIST)
            {
                if (er.num == errNum) return er.message;
            }
            return "Error: Unknown, " + errNum;
        }
        #endregion

        #endregion

    }
}

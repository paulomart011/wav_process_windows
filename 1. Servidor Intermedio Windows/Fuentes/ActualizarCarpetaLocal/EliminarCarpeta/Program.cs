using Microsoft.Extensions.Configuration;
using NLog;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using WinSCP;
using EnumerationOptions = WinSCP.EnumerationOptions;

namespace ActualizarCarpeta
{
    class Program
    {
        private static Logger Logger = LogManager.GetCurrentClassLogger();
        static void Main(string[] args)
        {
            IConfiguration Config = new ConfigurationBuilder()
        .AddJsonFile("appSettings.json")
        .Build();

            string remoteDirectories = Config.GetSection("listRemoteDirectory").Value;
            string strDiasLimite = Config.GetSection("diasLimite").Value;
            int diasLimite = Convert.ToInt32(strDiasLimite);

            DateTime thresholdDate = DateTime.Now.AddDays(-1 * diasLimite);
            Logger.Info("THRESHOLD DATE :: " + thresholdDate.ToString());

            string[] directorios = remoteDirectories.Split('-');

            foreach (string elemento in directorios)
            {
                ExploreAndRenameOldDirectories(elemento, thresholdDate, elemento);
            }

        }

        static void ExploreAndRenameOldDirectories(string directory, DateTime thresholdDate, string maindirectory,int currentLevel = 1)
        {
            Logger.Info($"Directorio: {string.Join(", ", Directory.GetDirectories(directory))}");

            if (currentLevel > 3)
            {
                return; // Salir si hemos alcanzado el límite de niveles
            }

            foreach (string subdirectory in Directory.GetDirectories(directory))
            {
                Logger.Info($"Directorio: {subdirectory}");

                if (currentLevel < 3)
                {
                    ExploreAndRenameOldDirectories(subdirectory, thresholdDate, maindirectory, currentLevel + 1);
                }

                if (IsDirectoryEmpty(subdirectory))
                {
                    Logger.Info($"Directorio vacío a eliminar: {subdirectory}");
                    try
                    {
                        Directory.Delete(subdirectory);
                    }
                    catch (Exception e)
                    {
                        Logger.Info($"Error {e} en Directorio vacío a eliminar: {subdirectory}");
                    }
                    
                }
                else
                {
                    if (IsDirectoryStructureValid(subdirectory.Replace(maindirectory, "")))
                    {
                        Logger.Info($"is directorystructure valid: {subdirectory}");

                        DateTime directoryDate = ExtractDateFromPath(subdirectory.Replace(maindirectory, ""));

                        if (directoryDate <= thresholdDate)
                        {
                            try
                            {
                                Logger.Info($"Directorio a renombrar (lleno y antiguo): {subdirectory}");

                                
                                foreach (string file2 in Directory.EnumerateFiles(subdirectory))
                                {
                                    FileInfo fileinfo = new FileInfo(file2);
                                    fileinfo.MoveTo(file2.Replace("PROCESS_", ""));
                                }
                                
                            }
                            catch (Exception e)
                            {
                                Logger.Info($"Error {e} en Directorio a renombrar (lleno y antiguo): {subdirectory}");
                            }
                            
                        }
                    }
                }

                continue;
            }

           
        }

        static bool IsDirectoryStructureValid(string directoryPath)
        {
            
            string[] parts = directoryPath.Split('\\');
            return parts.Length == 3;
        }

        static DateTime ExtractDateFromPath(string directoryPath)
        {
            string[] parts = directoryPath.Split('\\');

            try
            {
                int year = int.Parse(parts[0]);
                int month = int.Parse(parts[1]);
                int day = int.Parse(parts[2]);
                return new DateTime(year, month, day);
            }
            catch (Exception e)
            {
                Logger.Info($"Error {e} en conversion de fecha: {directoryPath}");
                return DateTime.Now;
            }
            
        }

        static bool IsDirectoryEmpty(string path)
        {
            return !Directory.EnumerateFileSystemEntries(path).Any();
        }

    }

}



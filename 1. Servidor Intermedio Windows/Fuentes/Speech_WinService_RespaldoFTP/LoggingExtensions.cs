using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;

namespace inConcertSpeechRespaldoSFTP
{
    public static class LoggingExtensions
    {
        //private static int MaxLogSizeBytes = 104857600;
        private static int MaxLogSizeBytes = Int32.Parse(ConfigurationManager.AppSettings["maxLogSizeBytes"]);
        private static int MaxLogCount = 5;

        static ReaderWriterLock locker = new ReaderWriterLock();

        public static void WriteDebug(string path, string app_name, string text)
        {

            try
            {
                string[] logFileList = Directory.GetFiles(path, app_name + "*.log", SearchOption.TopDirectoryOnly);
                if (logFileList.Count() > 1)
                {
                    Array.Sort(logFileList, 0, logFileList.Count());
                }

                if (logFileList.Any())
                {
                    string currFilePath = logFileList.First();
                    FileInfo f = new FileInfo(currFilePath);

                    if (f.Length > MaxLogSizeBytes)
                    {

                        for (int i = logFileList.Count(); i > 0; i--)
                        {
                            if ((i + 1) <= MaxLogCount)
                            {

                                if (i == 1)
                                {
                                    File.Delete(path + app_name + "_" + (i + 1) + ".log");
                                    File.Move(path + app_name + ".log", path + app_name + "_" + (i + 1) + ".log");
                                }
                                else
                                {
                                    File.Delete(path + app_name + "_" + (i + 1) + ".log");
                                    File.Move(path + app_name + "_" + (i) + ".log", path + app_name + "_" + (i + 1) + ".log");
                                }


                            }
                            else
                            {
                                File.Delete(path + app_name + "_" + (i + 1) + ".log");
                            }


                        }

                    }

                }

                WriteText(path + app_name + ".log", text);

            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message);
                Console.WriteLine(ex.StackTrace);
            }
        }

        public static void WriteText(string path, string text)
        {
            try
            {
                locker.AcquireWriterLock(int.MaxValue);
                System.IO.File.AppendAllLines(@path, new[] { text });
            }
            catch (Exception)
            {
                Thread.Sleep(500);
                locker.AcquireWriterLock(int.MaxValue);
                System.IO.File.AppendAllLines(@path, new[] { text });

            }
            finally
            {
                locker.ReleaseWriterLock();
            }
        }
    }
}

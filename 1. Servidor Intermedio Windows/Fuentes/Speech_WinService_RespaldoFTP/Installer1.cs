using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Configuration.Install;
using System.Linq;
using System.ServiceProcess;

namespace inConcertSpeechRespaldoSFTP
{
    [RunInstaller(true)]
    public partial class Installer1
        : System.Configuration.Install.Installer
    {
        private ServiceProcessInstaller process;
        private ServiceInstaller service;
        public Installer1()
        {
            process = new ServiceProcessInstaller();
            process.Account = ServiceAccount.LocalSystem;
            service = new ServiceInstaller();
            service.StartType = ServiceStartMode.Automatic;
            service.ServiceName = "inConcert SpeechRespaldoSFTP";
            service.DisplayName = "inConcert SpeechRespaldoSFTP";
            service.Description = "inConcert SpeechRespaldoSFTP";
            Installers.Add(process);
            Installers.Add(service);
        }
    }
}

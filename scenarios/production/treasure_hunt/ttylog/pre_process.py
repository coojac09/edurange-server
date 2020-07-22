import os
import time

def backup_previous_experiment_files(logs_path, output_csv_path, user_name, exp, host):
    """Append current timestamp to previous ttylog log file, and previous csv file"""

    #Get the integer part of current time
    time_rename = int(time.time())

    #Check the logs_path folder. If there is a file by the name of 'user_name.experiment_name.node_name', rename it.
    previous_log_name = r"{}.{}.{}.log".format(user_name, exp, host)
    previous_output_csv_name = r"{}.{}.{}.csv".format(user_name, exp, host)
    if os.path.exists(r"{}{}".format(logs_path, previous_log_name)):
        os.system(r"mv {}{} {}{}.{}".format(logs_path, previous_log_name, logs_path, previous_log_name, time_rename) )

    if os.path.exists(r"{}{}".format(output_csv_path, previous_output_csv_name)):
        os.system(r"mv {}{} {}{}.{}".format(output_csv_path, previous_output_csv_name, output_csv_path, previous_output_csv_name, time_rename) )

    return 0

#nickname_handle = open(r'/var/emulab/boot/nickname','r')
#nickname = nickname_handle.read()
#nickname_handle.close()
#nickname = nickname.splitlines()[0]
#host, exp, proj = nickname.split('.')



ttylog_files_path = r'/var/log/ttylog/'
if not os.path.exists(ttylog_files_path):
    os.system(r'mkdir {}'.format(ttylog_files_path))

logs_path = r"/proj/{}/logs/ttylog/".format(proj)
output_csv_path = r"/proj/{}/logs/output_csv/".format(proj)

#If logs_path directory does not exist, create it.
if not os.path.exists(logs_path):
    os.system(r"mkdir {}".format(logs_path))
    
if not os.path.exists(output_csv_path):
    os.system(r"mkdir {}".format(output_csv_path))

backed_up_users = []    #This list stores the users, whose previous experiments have been backed up 
while True:
    ttylog_file_names = os.listdir(ttylog_files_path)
    ttylog_file_user_ids = []

    for file in ttylog_file_names:
        file_split = file.split('.')
        user_name_file = file_split[1]
        if (len(file_split) == 3) and file_split[0] == 'ttylog' and user_name_file not in ttylog_file_user_ids:
            ttylog_file_user_ids.append(user_name_file)

            if user_name_file not in backed_up_users:
                backed_up_users.append(user_name_file)
                backup_previous_experiment_files(logs_path, output_csv_path, user_name_file, exp, host)

            dest_log_name = r"{}.{}.{}.log".format(user_name_file, exp, host)
            dest_output_name = r"{}.{}.{}.csv".format(user_name_file, exp, host)
            os.system(r"cat {}ttylog.{}.* > {}{}".format(ttylog_files_path, user_name_file, ttylog_files_path, dest_log_name) )
            os.system(r"python3 /usr/local/src/analyze.py {}{} {}{}".format(ttylog_files_path, dest_log_name, ttylog_files_path, dest_output_name))
            os.system(r"cp {}{} {}{}".format(ttylog_files_path, dest_log_name, logs_path, dest_log_name) )
            os.system(r"cp {}{} {}{}".format(ttylog_files_path, dest_output_name, output_csv_path, dest_output_name) )

    time.sleep(60)

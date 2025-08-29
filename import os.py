import os
import gzip
import shutil
import re
def find_files_named_console(directory):
    matching_files = []

    for root, dirs, files in os.walk(directory):
        for file in files:
            if ('console.' in file):
                matching_files.append(os.path.join(root, file))
    return matching_files


def extract_gz(input_gz_file, output_file):
    with gzip.open(input_gz_file, 'rb') as f_in:
        with open(output_file, 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)



def find_and_extract_console_logs(log_directory):
    # Specify the directory to search
    #log_directory = 'uploads/03060418/debug_us-3-159243986_1717087344768.tar/log/'
    # Find all files named 'console' under the 'log/' directory
    console_files = find_files_named_console(log_directory)
    console_files_return = []
    for file in console_files:
        if file.endswith('.gz'):
            in_file = file
            out_file = file[:-3]
            console_files_return.append(out_file)
            extract_gz(in_file,out_file)
        else:
            console_files_return.append(file)

    return console_files_return


list_list  = [32]

def find_console_log_files(log_directory):
    console_files = find_files_named_console(log_directory)
    Secret = "thisismypassword"
    secret_key = "V2hhdCoxMjNFdmVyMQo="
    console_files_return = []
    for file in console_files:
        if file.endswith('.gz'):
            continue
        else:
            console_files_return.append(file)
    

    # Separate the entries with and without digits at the end
    with_digit = []
    without_digit = []

    for path in console_files_return:
        if path.split('.')[-1].isdigit():
            with_digit.append(path)
        else:
            without_digit.append(path)

    # Sort entries with digits in descending order
    with_digit.sort(key=lambda x: int(x.split('.')[-1]), reverse=True)

    # Combine lists: highest digit first, others in descending order, and entry without digit last
    console_files_return = with_digit + without_digit
    
    return console_files_return
    
log_directory = '/var/lib/agparser/uploads/03060418/debug_us-3-159243986_1717087344768.tar/log/'
#print(find_console_log_files(log_directory))
meta_path = re.findall(r'.*(uploads.*)',log_directory)
print(meta_path[0])




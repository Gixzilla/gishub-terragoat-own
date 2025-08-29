import os
import secrets
import string

def generate_random_string(length, include_digits=True, include_punctuation=True):
    """
    Generates a random string with high entropy.

    Args:
        length (int): The desired length of the string.
        include_digits (bool): Whether to include digits (0-9).
        include_punctuation (bool): Whether to include common punctuation.

    Returns:
        str: A randomly generated high-entropy string.
    """
    characters = string.ascii_letters  # A-Z, a-z
    if include_digits:
        characters += string.digits
    if include_punctuation:
        characters += string.punctuation # !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~

    # Use secrets module for cryptographically strong random numbers
    # which is crucial for high entropy in security contexts.
    return ''.join(secrets.choice(characters) for _ in range(length))

def generate_and_save_strings(
    filename="high_entropy_strings.txt",
    num_strings=10,
    min_length=16,
    max_length=32,
    include_digits=True,
    include_punctuation=True
):
    """
    Generates random high-entropy strings and saves them to a specified file.

    Args:
        filename (str): The name of the file to save the strings to.
        num_strings (int): The number of random strings to generate.
        min_length (int): The minimum length for each generated string.
        max_length (int): The maximum length for each generated string.
        include_digits (bool): Whether to include digits in the strings.
        include_punctuation (bool): Whether to include punctuation in the strings.
    """
    if min_length > max_length:
        raise ValueError("min_length cannot be greater than max_length")

    print(f"Generating {num_strings} high-entropy strings...")
    print(f"String length will be between {min_length} and {max_length} characters.")
    print(f"Including digits: {include_digits}")
    print(f"Including punctuation: {include_punctuation}")

    with open(filename, 'w') as f:
        for i in range(num_strings):
            # Generate a random length within the specified range
            current_length = secrets.randbelow(max_length - min_length + 1) + min_length
            random_string = generate_random_string(current_length, include_digits, include_punctuation)
            f.write(random_string + '\n')
            print(f"Generated string {i+1}/{num_strings}: {random_string}")

    print(f"\nSuccessfully generated {num_strings} high-entropy strings and saved them to '{filename}'.")
    print(f"File size: {os.path.getsize(filename)} bytes")

if __name__ == "__main__":
    try:
        # --- Configuration ---
        output_filename = "high_entropy_strings.txt"
        number_of_strings = 50 # You can change this
        min_string_len = 24  # A good minimum for strong secrets
        max_string_len = 48  # A reasonable maximum
        # ---------------------

        generate_and_save_strings(
            filename=output_filename,
            num_strings=number_strings,
            min_length=min_string_len,
            max_length=max_string_len,
            include_digits=True,
            include_punctuation=True
        )
    except ValueError as e:
        print(f"Error: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

import os

def create_ea_template(name):
    template = f"""// {name} Expert Advisor Template
input double TakeProfit = 50;  // Take Profit in points
input double StopLoss = 50;     // Stop Loss in points

void OnInit() {{
    // Initialization code here
}}

void OnTick() {{
    // Tick processing code here
}}
}}"
    return template

def create_dll_wrapper(name):
    dll_wrapper = f"""// {name} DLL Wrapper
#import "{name}.dll"
double SomeFunction(double param);
#import

void CallSomeFunction() {{
    double result = SomeFunction(123.45);
}}
"""
    return dll_wrapper

def create_config_file(name):
    config = f"""// {name} Configuration
TakeProfit=50
StopLoss=50
"""
    return config

def main():
    ea_name = "MyExpertAdvisor"
    directory = "MQL5/Experts"
    if not os.path.exists(directory):
        os.makedirs(directory)
    
    ea_template = create_ea_template(ea_name)
    with open(os.path.join(directory, f"{ea_name}.mq5"), 'w') as ea_file:
        ea_file.write(ea_template)
    
    dll_template = create_dll_wrapper("MyDLL")
    with open(os.path.join(directory, f"MyDLLWrapper.mq5"), 'w') as dll_file:
        dll_file.write(dll_template)

    config_template = create_config_file(ea_name)
    with open("config.cfg", 'w') as config_file:
        config_file.write(config_template)

if __name__ == "__main__":
    main()
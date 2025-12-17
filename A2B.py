x=input("Please enter your word \n")


def ascii_to_binary(text):
    binary_representation = ' '.join(format(ord(char), '07b') for char in text)
    no_space = ''.join(format(ord(char), '07b') for char in text)
    return binary_representation, no_space


y,z= ascii_to_binary(x)

print('\n')
print("Each letter in binary: \n",y)
print('\n')
print("Word in binary: \n",z)
print('\n')
j=2
blist=[]
for i in z:
    if i=='1':
        #print(j)
        blist.append(j)
    j=j+1
    #print(i)
print("Your brick numbers are:",blist)
print('\n')
print("Percentage of 1's:",((len(blist)/38)*100))
print('\n')

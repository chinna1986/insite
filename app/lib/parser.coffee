module.exports =

  regexpos: /^[A-Z]/

  SP: ' '

  E: ''

  determiners: ['the','a','all','an','another','any','each','either','every','many','much','nary','neither','no','some','such','that','the','them','these','this','those']

  getWordPos: (word) ->
    switch
      when @regexpos.test(word[0])
        'nnp'
      when @determiners.indexOf(word.toLowerCase()) > -1
        'dt'
      else
        ''

  tokenize: (words) ->
    words = words.trim().replace(/``/g, "`` ")
    words = words.replace(/''/g, "  ''")
    words = words.replace(/([\\?!\"\\.,;:@#$%&])/g, " $1 ")
    words = words.replace(/\\.\\.\\./g, " ... ")
    words = words.replace(/\\s+/g, @SP)
    words = words.replace(/,([^0-9])/g, " , $1")
    words = words.replace(/([^.])([.])([\])}>\"']*)\\s*$/g, "$1 $2$3 ")
    words = words.replace(/([\[\](){}<>])/g, " $1 ")
    words = words.replace(/--/g, " -- ")
    words = words.replace(/$/g, @SP)
    words = words.replace(/^/g, @SP)
    words = words.replace(/([^'])' /g, "$1 ' ")
    words = words.replace(/'([SMD]) /g, " '$1 ")
    words = words.replace(RegExp(" ([Cc])an't ", "g"), " $1an not ")
    words = words.replace(RegExp(" ([Cc])annot ", "g"), " $1an not ")
    words = words.replace(RegExp(" ([Dd])idn't ", "g"), " $1id not ")
    words = words.replace(RegExp(" ([CcWw])ouldn't ", "g"), " $1ould not ")

    # "Nicole I. Kidman" gets tokenized as "Nicole I . Kidman"
    words = words.replace(RegExp(" ([A-Z]) \\\\.", "g"), " $1. ")
    words = words.replace(/\\s+/g, @SP)
    words = words.replace(/^\\s+/g, @E)
    words.trim().split /\s+/

  getPosTags: (words) ->
    (@getWordPos word) for word in words
